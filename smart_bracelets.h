
#ifndef SMART_BRACELETS_H
#define SMART_BRACELETS_H

//payload of the msg
typedef nx_struct my_msg {
	nx_uint8_t msg_type;
	nx_uint8_t key[20];
	nx_int8_t x;
    nx_int8_t y;
    nx_int8_t status;
} my_msg_t;

#define STANDING 11
#define WALKING 12
#define RUNNING 13
#define FALLING 14

typedef struct location{
  uint8_t x;
  uint8_t y;
  uint8_t status;
} loc;

#define PAIR 1
#define CONF 2
#define OPER 3



enum{
AM_MY_MSG = 6,
};

#endif
