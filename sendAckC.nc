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
	interface Timer<TMilli> as MilliTimer_pairing;
	interface Timer<TMilli> as MilliTimer_child;
	interface Timer<TMilli> as MilliTimer_alert;
    //other interfaces, if needed
    interface SplitControl;
    interface PacketAcknowledgements;
    interface Packet;
    interface AMPacket;
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<loc> as FakeSensor;
  }

} implementation {

  int random_p, random_c;
  char key_p[20], key_c[20];
  bool locked = FALSE;
  bool paired = FALSE;
  bool operation_mode = FALSE;
  message_t packet;

  am_addr_t pairing_address;
  loc last_child_loc;
  
  

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
	
	
	if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
		dbg("radio_send", "radio_send: request message type: %d. \n", msg->msg_type);
	}
	
	
 }        

  //****************** Task send response *****************//
  void check_pairing() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raises the event read done.
  	 */
  	 
  	 
	//call FakeSensor.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted, generating key for node %d...\n", TOS_NODE_ID);
	random_p = rand()%2;
	random_c = rand()%2; 
	
	if(TOS_NODE_ID%2 == 1){
		switch(random_p){
		case 0:
			strcpy(key_p, "4nchdjskcnfbghruejfn");
			break;
		case 1:
			strcpy(key_p, "8nchdde4kcnfbhr908fn");
			break;
		default:
			break;
		}
		dbg("boot", "random_p %d key_p = %s\n", random_p, key_p);
	}	
	
	if(TOS_NODE_ID%2 == 0){
		switch(random_c){
		case 0:
			strcpy(key_c, "4nchdjskcnfbghruejfn");
			break;
		case 1:
			strcpy(key_c, "8nchdde4kcnfbhr908fn");
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
  		call MilliTimer_pairing.startPeriodic(500);
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
  event void MilliTimer_pairing.fired() {
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
    	if (TOS_NODE_ID == 1){
    		memcpy(msg->key, key_p, 20);
    	}
    	else if (TOS_NODE_ID ==2){
    		memcpy(msg->key, key_c, 20);
        }
    	dbg("role", "mote: %u key %-20s\n", TOS_NODE_ID, msg->key);
		if (msg == NULL) {
			return;
		}

		sendReq();
    }
	
	
  }
  
  event void MilliTimer_child.fired() {
		dbg("operation_phase", "Call sensor read\n");
		call FakeSensor.read();
	}
	
	//***************** MilliTimer_alert interface ********************//
  event void MilliTimer_alert.fired() {
		dbg("alert", "ALERT! CHILD MISSING!:\n");
		dbg("alert", "location of the child, X = %hhu and Y = %hhu \n", last_child_loc.x, last_child_loc.y);
	}
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {

	 //Check if the ACK is received (read the docs)
	 if (&packet == buf && err == SUCCESS) {
	
	 dbg("radio_ack", "SEND DONE!!!!!!!!!\n");
	 locked = FALSE; 
	 
	 if(&packet == buf && call PacketAcknowledgements.wasAcked(buf)){
	
	 	 if (!paired){
	 	 	locked = FALSE; 

	 	 	dbg("radio_ack", "Still in pairing phase\n");
	 	 } 
	 	 
	 	}
	}
}

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check the type of message and do all the things that should be done
	 * 3. quando ricevi info -> fai partire timer di 60 sec e salva location in last_child_loc
	 */
	
	 
	if (len != sizeof(my_msg_t)) {return buf;}
	else {
	  my_msg_t* msg = (my_msg_t*)payload;
	  
	  dbg("radio_rec", "Received from mote %hhu packet type: %d, key: %s \n", call AMPacket.source(buf), msg->msg_type, msg->key);
	  
	
	  //no pairing yet
	  if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 1){
	  	dbg("role", "!!!!!!!!!!!info key_p: %s\n", key_p);
	 	if(strcmp(msg->key, key_p)==0){ 
	 		
	 		pairing_address = call AMPacket.source(buf);
	 		
	 		paired =TRUE;
      		dbg("role","Message before pairing received from %-14hhu|\n", pairing_address);
      		
      		call PacketAcknowledgements.requestAck(&packet); 
      		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
        		dbg("role", "pairing confirmation to node %hhu\n", pairing_address);	
        		locked = TRUE;
      		}
      	}
      	else{
      		dbg("role", "keys do not match. msg received from %hhu\n", call AMPacket.source(buf));
      	}
      } 
      
      if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 0){
	  	dbg("role", "!!!!!!!!!!!info key_c: %s\n", key_c);
	 	if(strcmp(msg->key, key_c)==0){ 
	 		
	 		pairing_address = call AMPacket.source(buf);
	 		paired =TRUE;
      		dbg("role","Message before pairing received from %-14hhu|\n", pairing_address);
      		
      		call PacketAcknowledgements.requestAck(&packet); 
      		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {

        		dbg("role", "pairing confirmation to node %hhu\n", pairing_address);	
        		locked = TRUE;
      		}
      	}
      	else{
      		dbg("role", "keys do not match. msg received from %hhu\n", call AMPacket.source(buf));
      	}
      }
      
      if(call AMPacket.destination(buf) == TOS_NODE_ID && paired){
      	call MilliTimer_pairing.stop();
	 	operation_mode = TRUE; //conclusa fase di pairing e continua fase di operation
	 		
	 	if (TOS_NODE_ID%2 == 0){ //nel caso di child
	 		call MilliTimer_child.startPeriodic(10000); //una info ogni 10 secondi
		}
      } 
      
      if (msg->msg_type == 3){
      	call MilliTimer_alert.startPeriodic(60000);
      	last_child_loc.x = msg->x;
      	last_child_loc.y = msg->y;
      	last_child_loc.status = msg->status;
      	dbg("role", "update last child location!\n");
      	if(msg->status == 14){
      		dbg("role", "ALERT!\n\n\n\n\n");
      	}
      } 
	  
	}
	return buf;
  }
  
  //************************* Read interface **********************//
  event void FakeSensor.readDone(error_t result, loc data) {

	// This event is triggered when the fake sensor finishes to read (after a Read.read()) 
 
	 my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	 
	 msg->x = data.x;
	 msg->y = data.y;
	 msg->status = data.status;
	 msg->msg_type = 3; //info type;
	  
	 call PacketAcknowledgements.requestAck(&packet); 
	
	 if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS && TOS_NODE_ID%2==0) {
		dbg("radio_send", "radio_send: response message type: %d.\n", msg->msg_type);
	 }
	 
}
}

