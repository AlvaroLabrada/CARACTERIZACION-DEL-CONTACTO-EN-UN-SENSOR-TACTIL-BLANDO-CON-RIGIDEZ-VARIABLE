clear all
close all
clear cam

camlist = webcamlist;
cam=webcam('UC60');
disp('Encendiendo cámara y ajustando luz...');

% Abre una ventana de previsualización. Esto activa el sensor
preview(cam); 

% Espera 0.05 segundos para que el auto-foco y la auto-exposición se ajusten
pause(0.05);
img = snapshot(cam); 
                
tiempo_actual = datetime('now'); %Obtener la hora actual
formato_archivo = 'yyyymmdd_HHMMss';
nombre_hora = datestr(tiempo_actual, formato_archivo);
    
% Crear el nombre de la primera foto
nombre_final = [nombre_hora, 'INICIO.jpg'];
imwrite(img, nombre_final);

ultima_foto=tic; % Inicia el temporizador
intervalo_fotos=1;
closePreview(cam);

while true
        %Tiempo que ha pasado desde que se llamó a tic o desde que se hizo
        %la última foto
        tiempo_transcurrido = toc(ultima_foto);

        if tiempo_transcurrido >= intervalo_fotos
            img = snapshot(cam); 
            tiempo_actual = datetime('now');                 
            formato_archivo = 'yyyymmdd_HHMMss';
            nombre_hora = datestr(tiempo_actual, formato_archivo);
            nombre_final = [nombre_hora, 'Esfera_flex_3_20.jpg'];
            imwrite(img, nombre_final);
            ultima_foto=tic;
        end
end

clear('cam');