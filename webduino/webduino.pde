/* 
Basic Arduino web server
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

#include <Ethernet.h>

// utility macros
#define CRLF "\r\n"
#define LEN(str) (sizeof(str) - 1)
#define P(name)   static const prog_uchar name[] PROGMEM

// configure for your own commands and security prefix
#define RELATIVE_URL "/foobar"
#define JSON_CMD "/json"
#define FORM_CMD "/form"

// CHANGE THIS TO YOUR OWN UNIQUE VALUE
static uint8_t mac[6] = { 0x02, 0xAA, 0xBB, 0xCC, 0x00, 0x22 };

// CHANGE THIS TO MATCH YOUR HOST NETWORK
static uint8_t ip[4] = { 192, 168, 42, 51 }; // area 51!

Server server = Server(80);

void setup()
{
  Ethernet.begin(mac, ip);
  server.begin();
  
  // set pins 0-9 for digital input
  for (int i = 0; i <= 9; ++i)
    pinMode(i, INPUT);
}

void sp_prg(const prog_uchar *str)
{
  char ch;
  while ((ch = pgm_read_byte(str++)))
    server.print(ch, BYTE);
}

void sp_crlf()
{
  server.print('\r', BYTE);
  server.print('\n', BYTE);
}

P(failMsg) = 
  "HTTP/1.0 400 Bad Request" CRLF
  "Content-Type: text/plain" CRLF
  CRLF
  "EPIC FAIL";

void http_fail()
{
  sp_prg(failMsg);
}

P(successMsg1) =
  "HTTP/1.0 200 OK" CRLF
  "Content-Type: ";

P(successMsg2) =
  "; charset=UTF-8" CRLF
  "Pragma: no-cache" CRLF;

P(successMsg3) =
  "Refresh: 1" CRLF;

void http_succeed(bool forceRefresh = false, const char *contentType = "text/html")
{
  sp_prg(successMsg1);
  server.print(contentType);
  sp_prg(successMsg2);
  if (forceRefresh)
    sp_prg(successMsg3);
  sp_crlf();
}

P(seeOtherMsg) =
  "HTTP/1.0 303 See Other" CRLF
  "Location: ";

void http_seeother(const char *otherURL)
{
  sp_prg(seeOtherMsg);
  server.print(otherURL);
  sp_crlf();
  sp_crlf();
}

#define INVALID_TYPE  0
#define GET_TYPE      1
#define HEAD_TYPE     2
#define POST_TYPE     3

struct url_option {
  const char *name;
  int value;
};

static char pushback[32];
static char pushback_depth = 0;

int read_char(Client &client)
{
  if (pushback_depth == 0)
    return client.read();
  else
    return pushback[--pushback_depth];
}

void push_char(char ch)
{
  pushback[pushback_depth++] = ch;
  // can't raise error here, so just replace last char over and over
  if (pushback_depth == sizeof(pushback))
    pushback_depth = sizeof(pushback) - 1;  
}

void reset_pushback()
{
  pushback_depth = 0;
}

bool expect_string(Client &client, const char *str)
{
  const char *curr = str;
  while (*curr != 0)
  {
    int ch = read_char(client);
    if (ch != *curr++)
    {
      // push back ch and the characters we accepted
      if (ch != -1)
        push_char(ch);
      while (--curr != str)
        push_char(curr[-1]);
      return false;
    }
  }
  return true;
}

void get_request(Client &client, char *type, char *request, int length, struct url_option* options = NULL)
{
  --length; // save room for NUL
  
  *type = INVALID_TYPE;

  // store the GET/POST line of the request
  if (expect_string(client, "GET "))
      *type = GET_TYPE;
  else if (expect_string(client, "HEAD "))
      *type = HEAD_TYPE;
  else if (expect_string(client, "POST "))
      *type = POST_TYPE;

  // if it doesn't start with any of those, we have an unknown method so just eat rest of header 

  int ch;
  while ((ch = read_char(client)) != -1)
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

void skip_headers(Client &client)
{
  // look for the CRLFCRLF at the end of the headers, read characters until then
  // store the GET/POST line of the request
  char state = 0;
  int ch; 
  while ((ch = read_char(client)) != -1)
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
  }
}

void process_post(Client &client)
{
  // FIXME - parse URL-encoded fields for changes
}



void radiobutton(int num, int val, const char *label, bool selected)
{
  server.print("<label><input type='radio' name='d");
  server.print(num);
  server.print("' value='");
  server.print(val);
  server.print("' ");
  if (selected)
    server.print("checked ");
  server.print("/> ");
  server.print(label);
  server.print("</label>");
}

void output_json_pins()
{
  int i;    
  http_succeed(false, "application/json");
  server.print("{ ");
  for (i = 0; i <= 13; ++i)
  {
    // ignore the pins we use to talk to the Ethernet chip
    if (i >= 10 && i <= 12)
      continue;
    int val = digitalRead(i);
    server.print("\"d");
    server.print(i);
    server.print("\": ");
    server.print(val);
    server.print(", ");
  }
        
  for (i = 0; i <= 5; ++i)
  {
    int val = analogRead(i);
    server.print("\"a");
    server.print(i);
    server.print("\": ");
    server.print(val);
    if (i != 5)
      server.print(", ");
  }
  
  server.print(" }");
}

P(htmlHead) =
  "<html>"
  "<head>"
  "<title>Arduino Web Server</title>"
  "<style type=\"text/css\">"
  "BODY { font-family: sans-serif }"
  "H1 { font-size: 14pt; text-decoration: underline }"
  "P  { font-size: 10pt; }"
  "</style>"
  "</head>"
  "<body>";

void output_pins(bool addControls = false)
{
  int i;    
  http_succeed();
  sp_prg(htmlHead);

  if (addControls)
    server.print("<form action='" RELATIVE_URL FORM_CMD "' method='post'>");
  
  server.print("<h1>Digital Pins</h1><p>");

  for (i = 0; i <= 13; ++i)
  {
    // ignore the pins we use to talk to the Ethernet chip
    if (i >= 10 && i <= 12)
      continue;
    int val = digitalRead(i);
    server.print("Digital ");
    server.print(i);
    server.print(": ");
    if (addControls)
    {
      radiobutton(i, 1, "On", val);
      server.print(" ");
      radiobutton(i, 0, "Off", !val);
    }
    else
      server.print(val ? "HIGH" : "LOW");

    server.print("<br/>");
  }
        
  server.print("</p><h1>Analog Pins</h1><p>");
  for (i = 0; i <= 5; ++i)
  {
    int val = analogRead(i);
    server.print("Analog ");
    server.print(i);
    server.print(": ");
    server.print(val);
    server.print("<br/>");
  }
      
  server.print("</p>");
  
  if (addControls)
    server.print("<input type='submit' value='Submit'/></form>");
  
  server.print("</body></html>");
}

void loop()
{
  int i;
  Client client = server.available();
  if (client) {
    static char request[32];
    request[0] = 0;
    char request_type = INVALID_TYPE; 
    get_request(client, &request_type, request, 32);
    
    if (request_type != INVALID_TYPE &&
        strncmp(request, RELATIVE_URL, LEN(RELATIVE_URL)) == 0)
    {
      switch (request_type)
      {
      case POST_TYPE:
        process_post(client);
        http_seeother(RELATIVE_URL FORM_CMD);
        break;
      case GET_TYPE:
        if (strncmp(request + LEN(RELATIVE_URL), JSON_CMD, LEN(JSON_CMD)) == 0)
          output_json_pins();
        else if (strncmp(request + LEN(RELATIVE_URL), FORM_CMD, LEN(FORM_CMD)) == 0)
          output_pins(true);
        else
          output_pins(false);
        break;
      case HEAD_TYPE:
        http_succeed();
        /* outputting success is enough */
        break;
      }
    }
    else
    {
      http_fail();
    }
    client.stop();
  }
}
