importScripts('https://www.gstatic.com/firebasejs/12.16.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.16.0/firebase-messaging-compat.js');

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
  const data = payload.data || {};
  const notificationId = /^[a-zA-Z0-9_-]{1,128}$/.test(data.notificacaoId || '')
    ? data.notificacaoId
    : '';
  const safeData = {
    tipo: 'atualizacao_clinica',
    ...(notificationId ? { notificacaoId: notificationId } : {}),
  };

  self.registration.showNotification('Nova atualização clínica', {
    body: 'Abra o Natus para visualizar os detalhes com segurança.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: safeData,
    tag: 'atualizacao_clinica',
    requireInteraction: false,
  });
});
