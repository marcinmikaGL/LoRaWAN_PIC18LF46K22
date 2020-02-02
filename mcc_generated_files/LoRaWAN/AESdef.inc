#define DECODE
#define ENCODE
#define CALCKEY
#ifndef NO_EXTERN
	EXTERN key
	EXTERN block
	#ifdef ENCODE
		EXTERN AESEncrypt
	#endif
	#ifdef DECODE
		EXTERN AESDecrypt
		#ifdef CALCKEY
			EXTERN AESCalcDecryptKey
		#endif
	#endif
#endif
