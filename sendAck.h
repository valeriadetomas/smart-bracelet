
#ifndef SENDACK_H
#define SENDACK_H

//payload of the msg
typedef nx_struct my_msg {
	nx_uint16_t counter;
	nx_uint16_t value;
	nx_uint16_t msg_type;
	nx_uint8_t key[20];
} my_msg_t;

/*typedef nx_struct pairing_msg{
	nx_uint16_t type;
	nx_uint16_t key[20];
	nx_uint16_t loc;
	nx_uint16_t id;
	nx_uint16_t value;
}pairing_msg_t;*/

#define STANDING 11
#define WALKING 12
#define RUNNING 13
#define FALLING 14

typedef struct location{
  uint16_t x;
  uint16_t y;
  uint8_t status;
} loc;

#define REQ 1
#define RESP 2 


enum{
AM_MY_MSG = 6,
};

#endif
