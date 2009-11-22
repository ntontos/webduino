/* Web_RSSFeed.pde - example sketch for Webduino library */

#include "Ethernet.h"
#include "WebServer.h"

/* CHANGE THIS TO YOUR OWN UNIQUE VALUE.  The MAC number should be
 * different from any other devices on your network or you'll have
 * problems receiving packets. */
static uint8_t mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

/* CHANGE THIS TO MATCH YOUR HOST NETWORK.  Most home networks are in
 * the 192.168.0.XXX or 192.168.1.XXX subrange.  Pick an address
 * that's not in use and isn't going to be automatically allocated by
 * DHCP from your router. */
static uint8_t ip[] = { 192, 168, 1, 64 };

/* set no prefix for this server.  We also will listen on port 80, the
 * standard HTTP service port */
WebServer webserver("", 80);

/* the analog light sensor on the Danger Shield is on analog input pin #3 */
#define LIGHT_SENSOR_PIN 3

/* we'll store the last 5 minutes of light data in this array, with a new 
 * reading done every 15 seconds. */
#define NUM_READINGS 20
int lightReading[20] = { 0 };

#define CHANNEL_TITLE "Webduino RSS Feed Example"
#define CHANNEL_DESCRIPTION "This is an example of serving RSS feeds from an Arduino web server."
#define CHANNEL_URL "http://webduino.googlecode.com"

/* This command is set as the handler for GET on feed.xml for the server.  It
 * handles the GET request for feed.xml. */
void rssFeedCmd(WebServer &server, WebServer::ConnectionType type, char *url_tail, bool tail_complete)
{
  if (type == WebServer::POST)
  {
    server.httpFail();
    return;
  }
  
  /* for a GET or HEAD, send the standard "it's all OK headers" */
  server.httpSuccess("application/rss+xml; charset=utf-8");

  /* we don't output the body for a HEAD request */
  if (type == WebServer::GET)
  {
    /* store the RSS 2.0 boilerplace in program memory using the P macro */
    P(channelStart) = 
      "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
      "<rss version=\"2.0\">"
      "<channel>"
      "<title>" CHANNEL_TITLE "</title>"
      "<description>" CHANNEL_DESCRIPTION "</description>"
      "<link>" CHANNEL_URL "</link>";
    P(channelEnd) = "</channel></rss>";
    P(itemStart) = "<item><description>";
    P(itemEnd) = "</description></item>\n";

    server.printP(channelStart);

    for (int i = 0; i < NUM_READINGS; ++i)
    {
       server.printP(itemStart);
       server.print("time = ");
       server.print(i * -15);
       server.print(" seconds, light = ");
       server.print(lightReading[i]);
       server.printP(itemEnd);
    }

    server.printP(channelEnd);
  }
}

/* This command is set as the handler for GET on feed.xml for the server.  It
 * handles the GET request for feed.xml. */
void defaultCmd(WebServer &server, WebServer::ConnectionType type, char *url_tail, bool tail_complete)
{
  if (type == WebServer::POST)
  {
    server.httpFail();
    return;
  }
  
  /* for a GET or HEAD, send the standard "it's all OK headers" */
  server.httpSuccess();

  /* we don't output the body for a HEAD request */
  if (type == WebServer::GET)
  {
    /* store the RSS 2.0 boilerplace in program memory using the P macro */
    P(defaultPage) = 
      "<html><body><p>See the <a href=\"rss.xml\">RSS feed</a> for light readings.</body></html>";
    server.printP(defaultPage);
  }
}

void setup()
{
  // setup the Ehternet library to talk to the Wiznet board
  Ethernet.begin(mac, ip);

  /* register our default command and feed command */
  webserver.setDefaultCommand(&defaultCmd);
  webserver.addCommand("rss.xml", rssFeedCmd);

  /* start the server to wait for connections */
  webserver.begin();
}

unsigned long lastTime = 0;

void loop()
{
  // process incoming connections one at a time forever
  webserver.processConnection();

  // check to see if 15 seconds are up -- if so, read another light
  // sensor setting and store it in the array
  unsigned long now = millis();
  if (lastTime = 0 || now - lastTime > 15000)
  {
    lastTime = now;

    // copy the old readings ahead one block
    for (int i = NUM_READINGS - 1; i > 0; --i)
    {
       lightReading[i] = lightReading[i - 1];
    }
  
    // read the new one into position 0
    lightReading[0] = analogRead(LIGHT_SENSOR_PIN);  
  }
}
