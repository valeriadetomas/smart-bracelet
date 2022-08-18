#include "sendAck.h"
#include "Timer.h"

module sendAckC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface Receive;
    interface AMSend;
	//interface for timer
	interface Timer<TMilli> as MilliTimer;
	//interface Timer<TMilli> as MilliTimer_pairing;
	//interface Timer<TMilli> as MilliTimer_child;
	//interface Timer<TMilli> as MilliTimer_alert;
    //other interfaces, if needed
    interface SplitControl;
    interface PacketAcknowledgements;
    interface Packet;
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<my_msg_t> as FakeSensor;
  }

} implementation {

  int random_p, random_c;
  char key_p[20], key_c[20];
  bool locked = FALSE;
  message_t packet;

  uint8_t last_digit = 7;
  uint8_t counter=0;
  uint8_t acks=0;
  uint8_t rec_id = 28;
  
  

  void sendReq();
  void sendResp();
  
  
  //***************** Send request function ********************//
  void sendReq() {
	/* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	
	
	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	
	
	call PacketAcknowledgements.requestAck(&packet); 
	
	
	if (call AMSend.send(2, &packet, sizeof(my_msg_t)) == SUCCESS && TOS_NODE_ID==1) {
		dbg("radio_send", "radio_send: request message type: %d. Counter: %hu \n", msg->msg_type, counter);
	}
	
	
 }        

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raises the event read done.
  	 */
	call FakeSensor.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted, generating key for node %d...\n", TOS_NODE_ID);
	random_p = rand()%2;
	random_c = rand()%2; 
	
	if(TOS_NODE_ID == 1){
		switch(random_p){
		case 0:
			strcpy(key_p, "4nchdjskcnfbghruejfn");
			break;
		case 1:
			strcpy(key_p, "4nchdde4kcnfbhr908fn");
			break;
		default:
			break;
		}
		dbg("boot", "random_p %d key_p = %s\n", random_p, key_p);
	}	
	
	if(TOS_NODE_ID == 2){
		switch(random_c){
		case 0:
			strcpy(key_c, "4nchdjskcnfbghruejfn");
			break;
		case 1:
			strcpy(key_c, "4nchdde4kcnfbhr908fn");
			break;
		default:
			break;
		}
		dbg("boot", "random_c %d key_c = %s\n", random_c, key_c);
	}
	
	call SplitControl.start();
	
	
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
  	/* Fill it ... */
  	if(err == SUCCESS){
  		dbg("boot", "success\n");
  		call MilliTimer.startPeriodic(1000);
  	}else{
  		dbg("boot", "else\n");
  		call SplitControl.start();
  	}
  }
  
  event void SplitControl.stopDone(error_t err){
    /* Fill it ... */
    dbg("boot", "finish\n");
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 * Fill this part...
	 */
    
    if(locked){
    	return;
    	
    }
    
    else{
    	
    	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
    	msg->msg_type = 1;
		if (msg == NULL) {
			return;
		}
		
		counter = counter +1;

		sendReq();
    }
	
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer according to your id. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	 
	 msg->counter = counter;
	 
	 if(&packet == buf && call PacketAcknowledgements.wasAcked(buf)){
	 	
	 	acks++;
	
	 	 if (msg -> msg_type ==1 && acks < last_digit){
	 	 	locked = FALSE; 
	 	 	msg->counter = counter;
	 	 	dbg("radio_ack", "radio_ack: the %dth ACK is received at counter %hu.\n", acks, counter);
	 	 } 
	 	 
	 	 else if (acks == last_digit){
	 	 	dbg("radio_ack", "radio_ack: the %dth ACK is received at counter %hu.\n", acks, counter);
	 	 	dbg("role", "role: ----- timer stopped at counter %hu -----.\n", msg->counter);
	 	 	call MilliTimer.stop();
	 	 }
	 }else{
	 	if(msg->counter < rec_id){
	 		locked = FALSE;
	 	}
	 }
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	
	 
	if (len != sizeof(my_msg_t)) {return buf;}
	else if(counter < rec_id + last_digit){
	  my_msg_t* msg = (my_msg_t*)payload;
	  dbg("radio_rec", "radio_rec: Received packet type: %d.\n", msg->msg_type);
	  sendResp();
	}
	return buf;
  }
  
  //************************* Read interface **********************//
  event void FakeSensor.readDone(error_t result, my_msg_t data) {

	/* This event is triggered when the fake sensor finishes to read (after a Read.read()) 
	 *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */

	 
	 my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	 
	 if(TOS_NODE_ID==2)
	 	//dbg("radio_pack", "radio_pack: Sensor read value %hu.\n", data);
	
	 msg->msg_type = RESP;
	 msg->value = data.value;
	 
	 
	 //call PacketAcknowledgements.requestAck(&packet); 
	
	
	 if (call AMSend.send(1, &packet, sizeof(my_msg_t)) == SUCCESS && TOS_NODE_ID==2) {
		dbg("radio_send", "radio_send: response message type: %d.\n", msg->msg_type);
	 }
	
	 
}
}

