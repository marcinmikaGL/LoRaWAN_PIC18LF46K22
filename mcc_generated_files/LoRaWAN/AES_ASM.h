extern unsigned char key[16];
extern unsigned char block[16];

#ifdef ENCODE
extern near void AESEncrypt(void);
#endif
#ifdef DECODE
extern near void AESDecrypt(void);
#endif
