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
		
		prob_number = call Random.rand16();
		
		
		if (prob_number%10 <= 2){
		  location.status = STANDING;
		} 
		if (prob_number%10 <= 5 && prob_number%10 >= 3){
		  location.status = WALKING;
		} 
		if (prob_number%10 <= 8 && prob_number%10 >=6){
		  location.status = RUNNING;
		} 
		else {
		  location.status = FALLING;
		}
		
		signal Read.readDone( SUCCESS, location);
	}
}


