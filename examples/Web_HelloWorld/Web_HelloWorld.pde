/* Web_HelloWorld.pde - very simple Webduino example */

#include "Ethernet.h"
#include "WebServer.h"

// CHANGE THIS TO YOUR OWN UNIQUE VALUE
static uint8_t mac[6] = { 0x02, 0xAA, 0xBB, 0xCC, 0x00, 0x22 };

// CHANGE THIS TO MATCH YOUR HOST NETWORK
static uint8_t ip[4] = { 192, 168, 42, 51 }; // area 51!

#define PREFIX "/"

WebServer webserver(PREFIX, 80);

// commands are functions that get called by the webserver framework
// they can read any posted data from client, and they output to server

void helloCmd(WebServer &server, WebServer::ConnectionType type)
{
  server.httpSuccess();
  if (type != WebServer::HEAD)
  {
    server.print("<h1>Hello, World!</h1>");
  }
}

void setup()
{
  Ethernet.begin(mac, ip);
  webserver.begin();

  webserver.setDefaultCommand(&helloCmd);
}

void loop()
{
  // process incoming connections one at a time forever
  webserver.processConnection();
}
