#include "sendAck.h"

configuration sendAckAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, sendAckC as App;
  //add the other components here
  components new TimerMilliC() as MilliTimer_pairing;
  components new TimerMilliC() as MilliTimer_child; //10s
  components new TimerMilliC() as MilliTimer_alert; //60s
  components ActiveMessageC;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components new FakeSensorC();

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  //Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  //Radio Control
  App.SplitControl -> ActiveMessageC;
  //Interfaces to access package fields
  App.PacketAcknowledgements -> AMSenderC;
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  //Timer interface
  App.MilliTimer_pairing -> MilliTimer_pairing;
  App.MilliTimer_child -> MilliTimer_child;
  App.MilliTimer_alert -> MilliTimer_alert;
  //Fake Sensor read
  App.FakeSensor -> FakeSensorC;

}

