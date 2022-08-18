 generic module FakeSensorP() {

	provides interface Read<my_msg_t>;
	
	uses interface Random;
	uses interface Timer<TMilli> as Timer0;

} implementation {

	my_msg_t msg;
	

	//***************** Boot interface ********************//
	command error_t Read.read(){
		call Timer0.startOneShot( 10 );
		return SUCCESS;
	}

	//***************** Timer0 interface ********************//
	event void Timer0.fired() {
		msg.x = call Random.rand16();
		msg.y = call Random.rand16();
		
		signal Read.readDone( SUCCESS,  msg);
	}
}


