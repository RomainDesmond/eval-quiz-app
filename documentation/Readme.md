Images preuves (Trivy + CI) : 
    Trivy (extension vscode) : <br>
        ![ ](trivy_vscode.png)
        <br>![alt text](image.png)    
        Changement d'image pour réduire le nombre de failles :
        <br>![alt text](image-2.png)
        <br>Changement après modifications des dockerfiles :
        <br>![alt text](image-3.png)
        <br>les ajouts ont été : db : USER postgre ; backend : USER node front : USER 65532 ainsi que  FROM nginxinc/nginx-unprivileged:alpine3.24 (avec apk upgrade --no-cache brotli-libs dans RUN pour corriger un CVE vers la fin)

<br>Information dans la CI :


ignore-unfixed: true  ,permet d'ignorer les failles sans correctif

on peut mettre scan-type mais de base c'est image donc non nécessaire

exit-code: '1' -> bloque la fusion (dans notre cas nécessaire)

Exemple CI Trivy : <br>![alt text](image-4.png)
<br>Exemple avec détail (ajouté dans le fichier trivy pour debug):
    <br>![alt text](image-5.png)
    <br>résultat : <br>![alt text](image-6.png)