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

	message_t packet;
	am_addr_t pairing_address;
	loc last_child_loc;

	bool pairing_mode[4] = {TRUE};
	bool operation_mode[4] = {FALSE};
       

//***************** Boot interface ********************//
	event void Boot.booted() {
		dbg("boot","BOOT: Application booted, generating key for mote %d...\n", TOS_NODE_ID);
	
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
	  		dbg("boot", "BOOT: success\n");
	  		call MilliTimer_pairing.startPeriodic(1000);
	  	}else{
	  		dbg("boot", "BOOT: failed\n");
	  		call SplitControl.start();
	  	}
  	}
  
	event void SplitControl.stopDone(error_t err){
		dbg("boot", "!!!!FINISH!!!!\n");
	}

//***************** MilliTimer interface ********************//
	event void MilliTimer_pairing.fired() {
    
		if(locked){return;}
		
		else{	
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			
			if (msg == NULL) {return;}
			
			msg->msg_type = PAIR; //PAIRING
			
			if (TOS_NODE_ID%2 == 1){
				memcpy(msg->key, key_p, 20);
			}
			else if (TOS_NODE_ID%2 == 0){
				memcpy(msg->key, key_c, 20);
		    }

			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
				dbg("radio_send", "RADIO_SEND: Sending broadcast message with key: %s\n", msg->key);
				locked = TRUE;
			}
		}
  	}

//***************** MilliTimer_child interface ********************// 
  	event void MilliTimer_child.fired() {
		dbg("role", "ROLE: Call sensor read\n");
		call FakeSensor.read();
	}

//***************** MilliTimer_alert interface ********************//
  	event void MilliTimer_alert.fired() {
  	
		dbg("alert", "************************************************\n");
  		dbg("alert", "**************** !!!!!ALERT!!!!! ***************\n");
  		dbg("alert", "************************************************\n");
  		dbg("alert", "************* !!!!!CHILD LOST!!!!! *************\n");
  		dbg("alert", "************************************************\n");
		dbg("alert", "ALERT: Last known location of the child, Coordinates: [X = %hhu; Y = %hhu]\n", last_child_loc.x, last_child_loc.y);
	}
  
//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

	 //Check if the ACK is received (read the docs)
		if (&packet == buf && err == SUCCESS) {
			
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			locked = FALSE; 
			//prima della fase di pairing
			if(pairing_mode[TOS_NODE_ID] && call PacketAcknowledgements.wasAcked(buf)){
				dbg("radio_ack", "RADIO_ACK: ACK received at time: %s\n", sim_time_string());
			}
			//nella fase di pairing
			else if(!pairing_mode[TOS_NODE_ID] && !operation_mode[TOS_NODE_ID] && call PacketAcknowledgements.wasAcked(buf)){
				dbg("role", "ROLE: !!!!PAIRING PHASE COMPLETED!!!!\n");
				
		 		call MilliTimer_pairing.stop(); 
		 		
		 		operation_mode[TOS_NODE_ID] = TRUE;
		 		pairing_mode[TOS_NODE_ID] = FALSE;
		 		//aggiungi pre op mode invece di settare di nuovo a false pairing mode
		 		if(TOS_NODE_ID%2 == 1){
          			call MilliTimer_alert.startOneShot(60000);
		 		}else{
		 			call MilliTimer_child.startPeriodic(10000);
		 		}
		 		
		 	}
		 	//nella fase operation
		 	else if(operation_mode[TOS_NODE_ID] && call PacketAcknowledgements.wasAcked(buf)){
		 		dbg("radio_ack", "RADIO_ACK: ACK received at time: %s\n", sim_time_string());
		 	}
		 	
		 	else if(operation_mode[TOS_NODE_ID] ){
		 		dbg("radio_ack", "RADIO_ACK: ACK NOT received\n");	
		 	}else if(pairing_mode[TOS_NODE_ID]){
		 		dbg("radio_ack", "RADIO_ACK: ACK NOT received\n");
		 	}	
		}
	}

//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	// This event is triggered when a message is received 
	
	 
		if (len != sizeof(my_msg_t)) {return buf;}
		else{
	  		my_msg_t* msg = (my_msg_t*)payload;
	  
	  	dbg("radio_rec", "RADIO_REC: Received from mote %hhu, massage type: %d\n", call AMPacket.source(buf), msg->msg_type);
	
	  
		  	if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 1 && strcmp(msg->key, key_p)==0){
		 		
			 		pairing_address = call AMPacket.source(buf);
			 		
			 		if(!locked){
			 			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			 			msg->msg_type = 2;
			 			pairing_mode[TOS_NODE_ID] = FALSE;
			 			call PacketAcknowledgements.requestAck( &packet );
			  		
				  		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
							dbg("radio_send", "RADIO_SEND: Sending pairing confirmation to mote %hhu\n", pairing_address);	
							locked = TRUE;
				  		}
			 		}
		  	}	 
		  	
		  	else if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && TOS_NODE_ID%2 == 0 && strcmp(msg->key, key_c)==0){ 
		 		
			 		pairing_address = call AMPacket.source(buf);
			 		
			 		if(!locked){
			 			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			 			msg->msg_type = 2;
			 			pairing_mode[TOS_NODE_ID]=FALSE;
			 			call PacketAcknowledgements.requestAck( &packet );
			  		
				  		if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
							dbg("radio_send", "RADIO_SEND: Sending pairing confirmation to mote %hhu\n", pairing_address);	
							locked = TRUE;
				  		}
			 		}
		  	}
		  	else if(call AMPacket.destination(buf) == AM_BROADCAST_ADDR ){
		  		dbg("radio_rec", "RADIO_REC: Keys do not match. Message received from mote %hhu\n", call AMPacket.source(buf));
		  	}
		  	
			else if(call AMPacket.destination(buf) == TOS_NODE_ID && msg->msg_type ==2){
				call MilliTimer_pairing.stop();
				operation_mode[TOS_NODE_ID] = TRUE;
				pairing_mode[TOS_NODE_ID] = FALSE; //conclusa fase di pairing e continua fase di operation
	
				if (TOS_NODE_ID%2 == 0){ //nel caso di child
					call MilliTimer_child.startPeriodic(10000); //una info ogni 10 secondi
				}else{
					call MilliTimer_alert.startOneShot(60000);
				}
			}
			
			else if(call AMPacket.destination(buf) == TOS_NODE_ID && msg->msg_type == 3){
			
			  	last_child_loc.x = msg->x;
			  	last_child_loc.y = msg->y;
			  	last_child_loc.status = msg->status;
			  	dbg("radio_rec", "RADIO_REC: Updating last child location!\n");
			  	if(msg->status == 14){
			  		dbg("alert", "************************************************\n");
			  		dbg("alert", "**************** !!!!!ALERT!!!!! ***************\n");
			  		dbg("alert", "************************************************\n");
			  		dbg("alert", "************* !!!!!CHILD FELL!!!!! *************\n");
			  		dbg("alert", "************************************************\n");
			  		dbg("alert", "ALERT: Child fall location coordinates: [X = %hhu; Y = %hhu]\n", last_child_loc.x, last_child_loc.y);
			  	}
			  	call MilliTimer_alert.startOneShot(60000);
			} 
		}
		return buf;
 	}
  
//************************* Read interface **********************//
	event void FakeSensor.readDone(error_t result, loc data) {

	// This event is triggered when the fake sensor finishes to read (after a Read.read()) 
		if (!locked) {
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		
			// Fill payload
			msg->x = data.x;
			msg->y = data.y;
			msg->status = data.status;
			msg->msg_type = 3; 
			operation_mode[TOS_NODE_ID] = TRUE;
			pairing_mode[TOS_NODE_ID] = FALSE;
			// Require ack
			call PacketAcknowledgements.requestAck(&packet); 
		
			if (call AMSend.send(pairing_address, &packet, sizeof(my_msg_t)) == SUCCESS) {
				dbg("radio_send", "RADIO_SEND: Sending message type: %d, status: %d. Coordinates: [X = %d, Y = %d]\n", msg->msg_type, msg->status, msg->x, msg->y);
		  		locked = TRUE;
			}
		 }
	}
}

