# Utilise une image Nginx officielle comme base
FROM nginx:latest

# Copie les fichiers de l'application dans le répertoire de Nginx
COPY app /usr/share/nginx/html

# Expose le port 80
EXPOSE 80

# Commande pour démarrer Nginx
CMD ["nginx", "-g", "daemon off;"]