/* 
Webduino, a simple Arduino web server
Copyright 2009 Ben Combee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include <string.h>
#include <stdlib.h>

#define WEBDUINO_VERSION 1001
#define WEBDUINO_VERSION_STRING "1.1"

// standard END-OF-LINE marker in HTTP
#define CRLF "\r\n"

// declare a static string
#define P(name)   static const prog_uchar name[] PROGMEM

// returns the number of elements in the array
#define SIZE(array) (sizeof(array) / sizeof(*array))

#ifndef WEBDUINO_FAIL_MESSAGE
#define WEBDUINO_FAIL_MESSAGE "<h1>EPIC FAIL</h1>"
#endif

class WebServer: public Server
{
public:
  // passed to a command to indicate what kind of request was received
  enum ConnectionType { INVALID, GET, HEAD, POST };

  // any commands registered with the web server have to follow
  // this prototype
  typedef void Command(WebServer &server, ConnectionType type);

  // constructor for webserver object
  WebServer(const char *urlPrefix = "/", int port = 80);

  // start listening for connections
  void begin();

  // check for an incoming connection, and if it exists, process it
  // by reading its request and calling the appropriate command
  // handler.
  void processConnection();

  // set command that's run when you access the root of the server
  void setDefaultCommand(Command *cmd);

  // set command run for undefined pages
  void setFailureCommand(Command *cmd);

  // add a new command to be run at the URL specified by verb
  void addCommand(const char *verb, Command *cmd);

  // utility function to output CRLF pair
  void printCRLF();
  
  // output a string stored in program memory, usually one defined
  // with the P macro
  void printP(const prog_uchar *str);

  // output raw data stored in RAM
  void write(const char *data, int length);

  // output raw data stored in program memory
  void writeP(const prog_uchar *data, int length);

  // output HTML for a radio button
  void radioButton(const char *name, const char *val, 
                   const char *label, bool selected);

  // output HTML for a checkbox
  void checkBox(const char *name, const char *val, 
                const char *label, bool selected);

  // returns next character or -1 if we're at end-of-stream
  int read();

  // put a character that's been read back into the input pool
  void push(char ch);
  
  // returns true if the string is next in the stream.  Doesn't
  // consume any character if false, so can be used to try out
  // different expected values.
  bool expect(const char *expectedStr);
  
  // returns true if we're not at end-of-stream
  bool readURLParam(char *name, int nameLen, char *value, int valueLen);

  // output headers and a message indicating a server error
  void httpFail();

  // output standard headers indicating "200 Success".  You can change the
  // type of the data you're outputting or also add extra headers like
  // "Refresh: 1".  Extra headers should each be terminated with CRLF.
  void httpSuccess(const char *contentType = "text/html; charset=utf-8", 
                   const char *extraHeaders = NULL);

  // used with POST to output a redirect to another URL.  This is
  // preferable to outputting HTML from a post because you can then
  // refresh the page without getting a "resubmit form" dialog.
  void httpSeeOther(const char *otherURL);

private:
  Client *m_client;
  const char *m_urlPrefix;

  char m_pushback[32];
  char m_pushbackDepth;

  Command *m_failureCmd;
  Command *m_defaultCmd;
  struct CommandMap
  {
    const char *verb;
    Command *cmd;
  } m_commands[8];
  char m_cmdCount;

  void reset();
  void getRequest(WebServer::ConnectionType &type, char *request, int length);
  bool dispatchCommand(ConnectionType requestType, const char *verb);
  void skipHeaders();
  void outputCheckboxOrRadio(const char *element, const char *name, 
                             const char *val, const char *label, 
                             bool selected);

  static void defaultFailCmd(WebServer &server, ConnectionType type);
  void noRobots();
};

WebServer::WebServer(const char *urlPrefix, int port) :
  Server(port), 
  m_client(0),
  m_urlPrefix(urlPrefix), 
  m_pushbackDepth(0),
  m_cmdCount(0), 
  m_failureCmd(&defaultFailCmd), 
  m_defaultCmd(&defaultFailCmd)
{
}

void WebServer::begin()
{
  Server::begin();
}

void WebServer::setDefaultCommand(Command *cmd)
{
  m_defaultCmd = cmd;
}

void WebServer::setFailureCommand(Command *cmd)
{
  m_failureCmd = cmd;
}

void WebServer::addCommand(const char *verb, Command *cmd)
{
  if (m_cmdCount < SIZE(m_commands))
  {
    m_commands[m_cmdCount].verb = verb;
    m_commands[m_cmdCount++].cmd = cmd;
  }
}

void WebServer::writeP(const prog_uchar *data, int length)
{
  char ch;
  while (length--)
  {
    ch = pgm_read_byte(data++);
    print(ch, BYTE);
  }
}

void WebServer::write(const char *data, int length)
{
  char ch;
  while (length--)
  {
    print(*(data++), BYTE);
  }
}

void WebServer::printP(const prog_uchar *str)
{
  char ch;
  while ((ch = pgm_read_byte(str++)))
    print(ch, BYTE);
}

void WebServer::printCRLF()
{
  print('\r', BYTE);
  print('\n', BYTE);
}

bool WebServer::dispatchCommand(ConnectionType requestType, const char *verb)
{
  if (verb[0] == 0)
  {
    m_defaultCmd(*this, requestType);
    return true;
  }
  
  if (verb[0] == '/')
  {
    if (verb[1] == 0)
    {
      m_defaultCmd(*this, requestType);
      return true;
    }
    else
    {
      char i;
      for (i = 0; i < m_cmdCount; ++i)
      {
        if (strcmp(verb + 1, m_commands[i].verb) == 0)
        {
          m_commands[i].cmd(*this, requestType);
          return true;
        }  
      }     
    }
  }    
  return false;
}

void WebServer::processConnection()
{
  Client client = available();
  if (client) {
    m_client = &client;

    static char request[32];
    request[0] = 0;
    ConnectionType requestType = INVALID; 
    getRequest(requestType, request, 32);
    skipHeaders();
    
    int urlPrefixLen = strlen(m_urlPrefix);
    if (requestType == GET &&
        strcmp(request, "robots.txt") == 0)
    {
      noRobots();
    }
    else if (requestType == INVALID ||
             strncmp(request, m_urlPrefix, urlPrefixLen) != 0 ||
             !dispatchCommand(requestType, request + urlPrefixLen))
    {
       m_failureCmd(*this, requestType);
    }

    client.stop();
    m_client = NULL;
  }
}

void WebServer::httpFail()
{
  P(failMsg) = 
    "HTTP/1.0 400 Bad Request" CRLF
    "Content-Type: text/html" CRLF
    CRLF
    WEBDUINO_FAIL_MESSAGE;

  printP(failMsg);
}

void WebServer::defaultFailCmd(WebServer &server, 
                               WebServer::ConnectionType type)
{
  server.httpFail();
}

void WebServer::noRobots()
{
  httpSuccess("text/plain");
  P(allowNoneMsg) = "User-agent: *" CRLF "Disallow: /" CRLF;
  printP(allowNoneMsg);
}

void WebServer::httpSuccess(const char *contentType, 
                            const char *extraHeaders)
{
  P(successMsg1) =
    "HTTP/1.0 200 OK" CRLF
    "Content-Type: ";

  printP(successMsg1);
  print(contentType);
  printCRLF();
  if (extraHeaders)
    print(extraHeaders);
  printCRLF();
}

void WebServer::httpSeeOther(const char *otherURL)
{
  P(seeOtherMsg) =
    "HTTP/1.0 303 See Other" CRLF
    "Location: ";

  printP(seeOtherMsg);
  print(otherURL);
  printCRLF();
  printCRLF();
}

int WebServer::read()
{
  if (m_pushbackDepth == 0)
    return m_client->read();
  else
    return m_pushback[--m_pushbackDepth];
}

void WebServer::push(char ch)
{
  m_pushback[m_pushbackDepth++] = ch;
  // can't raise error here, so just replace last char over and over
  if (m_pushbackDepth == SIZE(m_pushback))
    m_pushbackDepth = SIZE(m_pushback) - 1;  
}

void WebServer::reset()
{
  m_pushbackDepth = 0;
}

bool WebServer::expect(const char *str)
{
  const char *curr = str;
  while (*curr != 0)
  {
    int ch = read();
    if (ch != *curr++)
    {
      // push back ch and the characters we accepted
      if (ch != -1)
        push(ch);
      while (--curr != str)
        push(curr[-1]);
      return false;
    }
  }
  return true;
}

bool WebServer::readURLParam(char *name, int nameLen, 
                             char *value, int valueLen)
{
  // assume name is at current place in stream
  int ch;

  // clear out name and value so they'll be NUL terminated
  memset(name, 0, nameLen);
  memset(value, 0, valueLen);
  
  while ((ch = read()) != -1)
  {
    if (ch == '+')
    {
      ch = ' ';
    }
    else if (ch == '=')
    {
      /* that's end of name, so switch to storing in value */
      nameLen = 0;
      continue;
    }
    else if (ch == '&')
    {
      /* that's end of pair, go away */
      return true;
    }
    else if (ch == '%')
    {
      /* handle URL encoded characters by converting back to original form */
      int ch1 = read();
      int ch2 = read();
      if (ch1 == -1 || ch2 == -1)
         return false;
      char hex[3] = { ch1, ch2, 0 };
      ch = strtoul(hex, NULL, 16);
    }

    // check against 1 so we don't overwrite the final NUL
    if (nameLen > 1)
    {
      *name++ = ch;
      --nameLen;
    }
    else if (valueLen > 1)
    {
      *value++ = ch;
      --valueLen;
    }
  }
  return (ch != -1);
}
  
void WebServer::getRequest(WebServer::ConnectionType &type, 
                           char *request, int length)
{
  --length; // save room for NUL
  
  type = INVALID;

  // store the GET/POST line of the request
  if (expect("GET "))
      type = GET;
  else if (expect("HEAD "))
      type = HEAD;
  else if (expect("POST "))
      type = POST;

  // if it doesn't start with any of those, we have an unknown method so just eat rest of header 

  int ch;
  while ((ch = read()) != -1)
  {
    // stop storing at first space or end of line
    if (ch == ' ' || ch == '\n' || ch == '\r')
    {
      length = 0;
      break;
    }
    if (length > 0)
    {
      *request = ch;
      ++request;
      --length;
    }
  }
  // NUL terminate
  *request = 0;
}

void WebServer::skipHeaders()
{
  /* look for the double CRLF at the end of the headers, read
   * characters until then store the GET/POST line of the request */
  char state = 0;
  int ch; 
  while ((ch = read()) != -1)
  {
    if (ch == '\r')
    {
      if (state == 0) state = 1; 
      else if (state == 2) state = 3;
    }
    else if (ch == '\n') 
    { 
      if (state == 1) state = 2; 
      else if (state == 3) return; 
    }
    else
    {
      // any other character resets the search state
      state = 0;
    }
  }
}

void WebServer::outputCheckboxOrRadio(const char *element, const char *name, 
                                      const char *val, const char *label, 
                                      bool selected)
{
  P(cbPart1a) = "<label><input type='";
  P(cbPart1b) = "' name='";
  P(cbPart2) = "' value='";
  P(cbPart3) = "' ";
  P(cbChecked) = "checked ";
  P(cbPart4) = "/> ";
  P(cbPart5) = "</label>";

  printP(cbPart1a);
  print(element);
  printP(cbPart1b);
  print(name);
  printP(cbPart2);
  print(val);
  printP(cbPart3);
  if (selected)
    printP(cbChecked);
  printP(cbPart4);
  print(label);
  printP(cbPart5);
}

void WebServer::checkBox(const char *name, const char *val, 
                         const char *label, bool selected)
{
  outputCheckboxOrRadio("checkbox", name, val, label, selected);
}

void WebServer::radioButton(const char *name, const char *val, 
                            const char *label, bool selected)
{
  outputCheckboxOrRadio("radio", name, val, label, selected);
}
