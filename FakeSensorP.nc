 generic module FakeSensorP() {

	provides interface Read<loc>;
	uses interface Random;
	

} implementation {

	loc location;
	int prob_number;
	
	task void readDone();

	//***************** Boot interface ********************//
	command error_t Read.read(){
		post readDone();
		return SUCCESS;
	}

	
	task void readDone() {
		location.x = call Random.rand16();
	    location.y = call Random.rand16();
		
		prob_number = call Random.rand16()%10;
		
		
		if(prob_number <= 2){
		  location.status = STANDING;
		} 
		else if (prob_number<= 5){
		  location.status = WALKING;
		} 
		else if (prob_number <= 8){
		  location.status = RUNNING;
		} 
		else{
		  location.status = FALLING;
		}
		
		signal Read.readDone( SUCCESS, location);
	}
}


