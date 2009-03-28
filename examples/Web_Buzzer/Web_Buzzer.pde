/* Web_Buzzer.pde - example sketch for Webduino library */

#include "Ethernet.h"
#include "WebServer.h"

// CHANGE THIS TO YOUR OWN UNIQUE VALUE
static uint8_t mac[6] = { 0x02, 0xAA, 0xBB, 0xCC, 0x00, 0x22 };

// CHANGE THIS TO MATCH YOUR HOST NETWORK
static uint8_t ip[4] = { 192, 168, 42, 51 }; // area 51!

#define PREFIX "/buzz"

WebServer webserver(PREFIX, 80);

#define BUZZER_PIN 3
int buzzDelay = 0;
char toggle = 0; // used to alternate buzzer on/off cycle */

void buzzCmd(WebServer &server, WebServer::ConnectionType type)
{
  
  if (type == WebServer::POST)
  {
    bool repeat;
    char name[16], value[16];
    do
    {
      repeat = server.readURLParam(name, 16, value, 16);
      if (strcmp(name, "buzz") == 0)
      {
        buzzDelay = strtoul(value, NULL, 10);
      }
    } while (repeat);
    
    server.httpSeeOther(PREFIX "");
    return;
  }

  server.httpSuccess();
  if (type == WebServer::GET)
  {
    P(message) = 
      "<html><head><title>Webduino Buzzer Example</title>"
      "<body>"
      "<h1>Test the Buzzer!</h1>"
      "<form action='/buzz' method='POST'>"
      "<p><button name='buzz' value='0'>Turn if Off!</button></p>"
      "<p><button name='buzz' value='500'>500</button></p>"
      "<p><button name='buzz' value='1975'>1975</button></p>"
      "<p><button name='buzz' value='3000'>3000</button></p>"
      "<p><button name='buzz' value='8000'>8000</button></p>"
      "</form></body></html>";

    server.printP(message);
  }
}

void setup()
{
  // set pins 0-8 for digital input
  pinMode(BUZZER_PIN, OUTPUT);

  Ethernet.begin(mac, ip);
  webserver.begin();

  webserver.setDefaultCommand(&buzzCmd);
}

void loop()
{
  // process incoming connections one at a time forever
  webserver.processConnection();

  if ((++toggle & 1) && (buzzDelay > 0))
  {
    digitalWrite(BUZZER_PIN, HIGH);
    delayMicroseconds(buzzDelay);
    digitalWrite(BUZZER_PIN, LOW);
  }
}
