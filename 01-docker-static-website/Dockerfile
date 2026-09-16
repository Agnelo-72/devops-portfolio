#imagem base: usamos Alpine por ser leve e eficiente
FROM nginx:alpine

#copiamos os arquivos do site para o diretorio do Nginx
COPY website/ /usr/share/nginx/html/

#informamos que o container usará a porta 80
EXPOSE 80

#iniciar o servidor Nginx
CMD ["nginx", "-g", "daemon off;"]

# -g: flag para passar comandos globais ao Nginx
# daemon off;: mantém o Nginx rodando em primeiro plano