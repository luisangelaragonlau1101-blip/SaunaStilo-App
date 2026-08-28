importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCqvb1kOvxvPTZzCZLQx6aZgEBnC-AZnYE',
  authDomain: 'saunastiloapp-17e15.firebaseapp.com',
  projectId: 'saunastiloapp-17e15',
  storageBucket: 'saunastiloapp-17e15.firebasestorage.app',
  messagingSenderId: '1083212885362',
  appId: '1:1083212885362:web:0b99846f25c4d5c005c1eb'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[push] Notificación recibida en segundo plano', payload.messageId);
});
