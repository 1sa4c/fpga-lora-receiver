#include "Ultrasonic.h"
#include "SoftwareSerial.h"

#define RX 2
#define TX 3

SoftwareSerial lora(RX, TX);
Ultrasonic ultrasonic(7, 8);

int distance, last_distance;
uint8_t speed, last_speed;
unsigned long time, last_time, last_accident;
const byte ID = B01000000;
const byte accident_check = B00100000;
byte b_speed = "00011010";
byte packet;
bool hasCrashed = false;
 
void setup() {
  Serial.begin(9600);
  lora.begin(9600);

  Serial.println("[*] Initializing transmitter setup.");

  last_time = 0;
  last_distance = ultrasonic.read();

  Serial.println("[*] Setup done.");
}
 
void loop() {
  
  distance = ultrasonic.read();
  time = millis();

  if((time - last_time) >= 50){
    last_speed = speed;
    speed = (distance - last_distance) / (time - last_time);
    b_speed = byte(max(speed, last_speed));
    last_time = time;

    if(distance <= 5){
      if(!hasCrashed){
        hasCrashed = true;
        last_accident = time;
        Serial.println("[*] Accident detected.");
        packet = ID | accident_check | b_speed;
        lora.write(packet);
        Serial.println("[*] Packet sent.");
        delay(500);
      }
    } else {
      if(hasCrashed && (time - last_accident >= 7000)){
        hasCrashed = false;
      }
    }

    //Serial.println(distance);
  }



}