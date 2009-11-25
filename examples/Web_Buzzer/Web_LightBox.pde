/* Web_LightBox.pde - example sketch for Webduino library */

#include "Ethernet.h"
#include "WebServer.h"

/* CHANGE THIS TO YOUR OWN UNIQUE VALUE.  The MAC number should be
 * different from any other devices on your network or you'll have
 * problems receiving packets. */
static uint8_t mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0x10 };

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

/* This command is set as the handler for GET on feed.xml for the server.  It
 * handles the GET request for feed.xml. */
void lightJsonCmd(WebServer &server, WebServer::ConnectionType type, char *url_tail, bool tail_complete)
{
  if (type == WebServer::POST)
  {
    server.httpFail();
    return;
  }
  
  /* for a GET or HEAD, send the standard "it's all OK headers" */
  server.httpSuccess("application/json");

  /* we don't output the body for a HEAD request */
  if (type == WebServer::GET)
  {
    server.print("{ \"light\": ");
    server.print(analogRead(LIGHT_SENSOR_PIN));
    server.print(" }");
  }
}

/* This command is set as the handler for GET on the default page.  It returns an HTML page
 * that has JavaScript to fetch the light reading over and over and adjust the background
 * color of the page. */
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
      "<html><head>"
        "<script type=\"text/javascript\" src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.3/jquery.min.js\"></script>"
        "<script>\n"
        "function updateBackground() {\n"
        "$.getJSON('light.json', function(json) {\n" 
          "var grey = Math.floor(json.light / 4);\n"
          "$('body').css('background-color', 'rgb(' + grey + ',' + grey + ',' + grey + ')');\n"
          "setTimeout(function(){updateBackground();}, 200); })}\n"
        "$(window).load(function(){ updateBackground();});\n"
        "</script>"
      "</head>"
      "<body>"
        "<p>This page is checking the light sensor on the Danger Shield five times a second and pulling down a JSON file "
        "with the new value.  This is used to alter the page background color, with darker light readings making the "
        " background darker.</p>"
        "<p><a href=\"light.json\">A link to the JSON file.</a></p>"
      "</body></html>";
    server.printP(defaultPage);
  }
}

void setup()
{
  // setup the Ehternet library to talk to the Wiznet board
  Ethernet.begin(mac, ip);

  /* register our default command and feed command */
  webserver.setDefaultCommand(&defaultCmd);
  webserver.addCommand("light.json", lightJsonCmd);

  /* start the server to wait for connections */
  webserver.begin();
}

void loop()
{
  // process incoming connections one at a time forever
  webserver.processConnection();
}
