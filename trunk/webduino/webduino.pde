/* 
Webduino - basic Arduino web server
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
#include "WebServer.h"

// CHANGE THIS TO YOUR OWN UNIQUE VALUE
static uint8_t mac[6] = { 0x02, 0xAA, 0xBB, 0xCC, 0x00, 0x22 };

// CHANGE THIS TO MATCH YOUR HOST NETWORK
static uint8_t ip[4] = { 192, 168, 42, 51 }; // area 51!

#define PREFIX "/demo"

WebServer webserver(PREFIX, 80);

// commands are functions that get called by the webserver framework
// they can read any posted data from client, and they output to server

void jsonCmd(WebServer &server, WebServer::ConnectionType type)
{
  if (type == WebServer::POST)
  {
    server.httpFail();
    return;
  }

  server.httpSuccess(false, "application/json");
  
  if (type == WebServer::HEAD)
    return;
    
  int i;    
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

void outputPins(WebServer &server, WebServer::ConnectionType type, bool addControls = false)
{
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

  int i;
  server.httpSuccess();
  server.printP(htmlHead);

  if (addControls)
    server.print("<form action='" PREFIX "/form' method='post'>");
  
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
      char pinName[4];
      pinName[0] = 'd';
      itoa(i, pinName + 1, 10);
      server.radioButton(pinName, "1", "On", val);
      server.print(" ");
      server.radioButton(pinName, "0", "Off", !val);
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

void formCmd(WebServer &server, WebServer::ConnectionType type)
{
  if (type == WebServer::POST)
    // fixme
    server.httpSeeOther(PREFIX);
  else
    outputPins(server, type, true);
}

void defaultCmd(WebServer &server, WebServer::ConnectionType type)
{
  outputPins(server, type, false);  
}

void setup()
{
  // set pins 0-9 for digital input
  for (int i = 0; i <= 9; ++i)
    pinMode(i, INPUT);

  Ethernet.begin(mac, ip);
  webserver.begin();

  webserver.setDefaultCommand(&defaultCmd);
  webserver.addCommand("json", &jsonCmd);
  webserver.addCommand("form", &jsonCmd);
}

void loop()
{
  // process incoming connections one at a time forever
  webserver.processConnection();

  // if you wanted to do other work based on a connecton, it would go here
}
