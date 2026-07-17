importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB3irHorITGhIAlxVYzgHewkGmI3eVQQMY',
  appId: '1:1078564037217:web:d630421cef24e5746f4020',
  messagingSenderId: '1078564037217',
  projectId: 'natus-gestantes',
  authDomain: 'natus-gestantes.firebaseapp.com',
  storageBucket: 'natus-gestantes.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};

  const title = notification.title || data.title || 'Natus';
  const body = notification.body || data.body || 'Você recebeu uma nova atualização.';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
    tag: data.tag || data.tipo || 'natus-alerta',
    requireInteraction: data.tipo === 'alerta_contracao',
  });
});
