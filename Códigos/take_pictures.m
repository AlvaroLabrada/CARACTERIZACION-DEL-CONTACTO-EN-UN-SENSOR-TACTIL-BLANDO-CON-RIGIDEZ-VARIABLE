clear all
close all
clear cam

camlist = webcamlist;

cam=webcam('UC60');

% FASE DE CALENTAMIENTO (SOLUCIÓN A FOTO BLANCA)
disp('Encendiendo cámara y ajustando luz...');

% Abre una ventana de previsualización. Esto activa el sensor
preview(cam); 

% Esperamos 0.01 segundos para que el auto-foco y la auto-exposición se ajusten
pause(0.01);
img = snapshot(cam); 
                
            % 5. Obtener la hora actual
            tiempo_actual = datetime('now'); 
                
            % Formato: AñoMesDía_HoraMinutoSegundo
            formato_archivo = 'yyyymmdd_HHMMss';
            nombre_hora = datestr(tiempo_actual, formato_archivo);
                
            % 6. Crear el nombre final con la extensión .jpg
            nombre_final = [nombre_hora, 'INICIO.jpg'];
            % Se guarda en la carpeta donde se está ejecutando el script de Matlab.
            imwrite(img, nombre_final);

ultima_foto=tic;
intervalo_fotos=10;
closePreview(cam);

while true
        %Tiempo que ha pasado desde que se llamó a tic o desde que se hizo
        %la última foto
        tiempo_transcurrido = toc(ultima_foto);

        if tiempo_transcurrido >= intervalo_fotos
            img = snapshot(cam); 
                
            % 5. Obtener la hora actual
            tiempo_actual = datetime('now'); 
                
            % Formato: AñoMesDía_HoraMinutoSegundo (ej: '20251125_183636')
            formato_archivo = 'yyyymmdd_HHMMss';
            nombre_hora = datestr(tiempo_actual, formato_archivo);
                
            % 6. Crear el nombre final con la extensión .jpg
            nombre_final = [nombre_hora, 'Esfera_raja_reciente_30_cel500.jpg'];
            % Se guarda en la carpeta donde se está ejecutando el script de Matlab.
            imwrite(img, nombre_final);
            
            ultima_foto=tic;
        end
    % pause(0.01); %Pausa para no saturar la CPU
end

clear('cam');