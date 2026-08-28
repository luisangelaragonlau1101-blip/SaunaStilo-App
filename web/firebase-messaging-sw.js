importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAL8Z_Fwa9RurlvPdxGZYJEf5TVmlahUnA',
  authDomain: 'saunastylo-dbd87.firebaseapp.com',
  projectId: 'saunastylo-dbd87',
  storageBucket: 'saunastylo-dbd87.firebasestorage.app',
  messagingSenderId: '905977113744',
  appId: '1:905977113744:android:dd7961093ce84813f27c15'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[push] Notificación recibida en segundo plano', payload.messageId);
});
