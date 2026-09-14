{{flutter_js}}
{{flutter_build_config}}

// O cache offline do Flutter e o worker do Firebase Messaging disputam o
// mesmo escopo. Mantemos apenas o worker de notificacoes registrado no
// index.html e deixamos os assets HTTP serem revalidados pelo Hosting.
_flutter.loader.load();
