#include "smart_bracelets.h"
#include "Timer.h"

module smart_braceletsC {

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

}implementation{

	char key_p[20], key_c[20];
	bool locked = FALSE;
	bool paired[4] = {FALSE};
	bool operation_mode[4] = {FALSE};
	message_t packet;
	am_addr_t pairing_address;
	loc last_child_loc;

	void sendReq();
	void sendResp();
  
  
  //***************** Send request function ********************//
	void sendReq() {
	/* This function is called when we want to send a request */

		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

		call PacketAcknowledgements.requestAck(&packet); 

		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
			dbg("radio_send", "radio_send: request message type: %d. \n", msg->msg_type);
			locked = TRUE;
		}
	}        

//***************** Boot interface ********************//
	event void Boot.booted() {
		dbg("boot","Application booted, generating key for node %d...\n", TOS_NODE_ID);
	
		switch(TOS_NODE_ID){
			case 1:
				strcpy(key_p, "4nchdjskcnfbghruejfn");
				break;
			case 2:
				strcpy(key_c, "4nchdjskcnfbghruejfn");
				break;
			case 3:
				strcpy(key_p, "8nchdde4kcnfbhr908fn");
				break;
			case 4:
				strcpy(key_c, "8nchdde4kcnfbhr908fn");
				break;
			default:
				break;
			}
	
		call SplitControl.start();
	}

//***************** SplitControl interface ********************//
	event void SplitControl.startDone(error_t err){
	  	
	  	if(err == SUCCESS){
	  		dbg("boot", "boot: success\n");
	  		call MilliTimer_pairing.startPeriodic(500);
	  	}else{
	  		dbg("boot", "boot: failed\n");
	  		call SplitControl.start();
	  	}
  	}
  
	event void SplitControl.stopDone(error_t err){
		dbg("boot", "finish\n");
	}

//***************** MilliTimer interface ********************//
	event void MilliTimer_pairing.fired() {
    
		if(locked){return;}
		
		else{	
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			
			if (msg == NULL) {return;}
			
			msg->msg_type = 1; //PAIRING
			
			if (TOS_NODE_ID%2 == 1){
				memcpy(msg->key, key_p, 20);
			}
			else if (TOS_NODE_ID%2 == 0){
				memcpy(msg->key, key_c, 20);
		    }
			dbg("role", "role: Assigned key to mote: %u. KEY %-20s\n", TOS_NODE_ID, msg->key);
			
			

			sendReq();
		}
  	}

//***************** MilliTimer_child interface ********************// 
  	event void MilliTimer_child.fired() {
		dbg("operation_phase", "Call sensor read\n");
		call FakeSensor.read();
	}

//***************** MilliTimer_alert interface ********************//
  	event void MilliTimer_alert.fired() {
  	
		dbg("alert", "************************************************\n");
  		dbg("alert", "**************** !!!!!ALERT!!!!! ***************\n");
  		dbg("alert", "************************************************\n");
  		dbg("alert", "************* !!!!!CHILD LOST!!!!! *************\n");
  		dbg("alert", "************************************************\n");
		dbg("alert", "alert: Last known location of the child, Coordinates: [X = %hhu; Y = %hhu] \n", last_child_loc.x, last_child_loc.y);
	}
  
//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

	 //Check if the ACK is received (read the docs)
		if (&packet == buf && err == SUCCESS) {
			locked = FALSE; 
		 
		 	if(paired[TOS_NODE_ID] && call PacketAcknowledgements.wasAcked(buf)){
				dbg("radio_ack", "radio_ack: message was acked at time: %s \n", sim_time_string());
				
		 		call MilliTimer_pairing.stop(); 
		 		operation_mode[TOS_NODE_ID] = TRUE;
		 		
		 		if(TOS_NODE_ID%2 == 1){
          			call MilliTimer_alert.startOneShot(60000);
		 		}else{
		 			call MilliTimer_child.startPeriodic(10000);
		 		}
		 		
		 	}else if(operation_mode[TOS_NODE_ID]){
		 		call FakeSensor.read();
		 	}
		}
	}

//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	// This event is triggered when a message is received 
	
	 
		if (len != sizeof(my_msg_t)) {return buf;}
		else{
	  		my_msg_t* msg = (my_msg_t*)payload;
	  
	  	dbg("radio_rec", "radio_rec: received from mote %hhu type: %d \n", call AMPacket.source(buf), msg->msg_type);
	
	  
	  	if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 1){
	 		if(strcmp(msg->key, key_p)==0){ 
	 		
		 		pairing_address = call AMPacket.source(buf);
		 		paired[TOS_NODE_ID] = TRUE;
		 		
		 		if(!locked){
		 			call PacketAcknowledgements.requestAck( &packet );
		  		
			  		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
						dbg("radio_send", "radio_send: pairing confirmation to node %hhu\n", pairing_address);	
						locked = TRUE;
			  		}
		 		}
		 		
      		}else{
      			dbg("role", "role: keys do not match. msg received from %hhu\n", call AMPacket.source(buf));
      		}
      	}	 
      	
      	if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 0){
		 	if(strcmp(msg->key, key_c)==0){ 
		 		
		 		pairing_address = call AMPacket.source(buf);
		 		paired[TOS_NODE_ID] = TRUE;
		  		
		  		if(!locked){
		 			call PacketAcknowledgements.requestAck( &packet );
		  		
			  		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
						dbg("radio_send", "radio_send: pairing confirmation to node %hhu\n", pairing_address);	
						locked = TRUE;
			  		}
		 		}
		  	}else{
		  		dbg("role", "role: keys do not match. msg received from %hhu\n", call AMPacket.source(buf));
		  	}
		  }
		  
		  if(call AMPacket.destination(buf) == TOS_NODE_ID && paired[TOS_NODE_ID]){
		  	call MilliTimer_pairing.stop();
		 	operation_mode[TOS_NODE_ID] = TRUE; //conclusa fase di pairing e continua fase di operation
		 		
		 	if (TOS_NODE_ID%2 == 0){ //nel caso di child
		 		call MilliTimer_child.startPeriodic(10000); //una info ogni 10 secondi
			}else{
				call MilliTimer_alert.startOneShot(60000);
			}
		  } 
		  
		  if (msg->msg_type == 3){
		  	last_child_loc.x = msg->x;
		  	last_child_loc.y = msg->y;
		  	last_child_loc.status = msg->status;
		  	dbg("role", "info: update last child location!\n");
		  	if(msg->status == 14){
		  		dbg("role", "************************************************\n");
		  		dbg("role", "**************** !!!!!ALERT!!!!! ***************\n");
		  		dbg("role", "************************************************\n");
		  		dbg("role", "************* !!!!!CHILD FELL!!!!! *************\n");
		  		dbg("role", "************************************************\n");
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
		  
		 dbg("radio_send", "radio_send: Child status: %d.\n", msg->status);
		 call PacketAcknowledgements.requestAck(&packet); 
	
		 if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS && TOS_NODE_ID%2==0) {
			dbg("radio_send", "radio_send: response message type: %d.\n", msg->msg_type);
		    dbg("radio_send", "INFO MSG: Status %d. Coordinates: [X = %d, Y = %d].\n", msg->status, msg->x, msg->y);
		} 
	}
}

