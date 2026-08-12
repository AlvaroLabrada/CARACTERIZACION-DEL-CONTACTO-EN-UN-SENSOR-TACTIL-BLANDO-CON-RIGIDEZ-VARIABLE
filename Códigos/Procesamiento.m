%% Cambiar las siguientes líneas en función del experimento:
%Datos de la Mecmesin: Líneas 9 y 10
%Frecuencia de la Mecmesin: Línea 28
%Imagenes: Líneas 35 y 36
clear; clc; close all;


%% Leer el excel con los datos de la mecmesin
carpeta_datos = 'C:\Users\ALVARO\OneDrive - Universidad de Castilla-La Mancha\RobInd - AlvaroLabrada\Datos experimentos\Experimentos Alvaro';
humedad = '20';
nombre_archivo = 'Esfera_flex_3_20.csv';
ruta_excel = fullfile(carpeta_datos,humedad, nombre_archivo);

fid = fopen(ruta_excel, 'r');
textscan(fid, '%s', 4, 'Delimiter', '\n'); % saltar las 4 primeras líneas
raw = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', ''); % leer el resto del archivo línea a línea como texto
fclose(fid);

texto = strrep(strjoin(raw{1}, '\n'), ',', '.'); % unir todas las líneas y sustituir comas por puntos

datos = textscan(texto, '%f%f%f%*f', 'Delimiter', ';'); % convertir las 3 primeras columnas a números (descartar la 4ª)
tabla_datos = table(datos{1}, datos{2}, datos{3}, 'VariableNames', {'Fuerza', 'Distance', 'Time'});

% Convertir tiempo de minutos a segundos
tabla_datos.Time = tabla_datos.Time * 60;

% Extraer filas cada 10 segundos, es decir, cada 1000 muestras
frecuencia = 10; % Cada cuantos segundos se extraen los datos
intervalo = 100 * frecuencia ; % Los segundos se pasan a número de muestras
indices=intervalo:intervalo:height(tabla_datos);
tabla_recortada=tabla_datos(indices,:);

%% Leer múltiples imágenes (orden cronológico real)
carpeta_imagenes = 'C:\Users\ALVARO\OneDrive - Universidad de Castilla-La Mancha\RobInd - AlvaroLabrada\Restante';
sufijo = 'Esfera_flex_3_20_cel500';
extension = '.jpg';

% Buscar todo los archivos que coincidan con el sufijo y la extensión
archivos = dir(fullfile(carpeta_imagenes, ['*' sufijo extension]));

% Ordenar por cronológicamente mediante sus nombres
nombres = sort({archivos.name});

% Asegurar que el número de imágenes que se leen coincide con los datos tomados
n_imagenes = height(tabla_recortada);
imagenes = cell(n_imagenes, 1);

if  n_imagenes > length(archivos)
    n_imagenes = length(archivos);
    indices=indices(1:length(archivos));
    tabla_recortada=tabla_datos(indices,:);
end
   
for i = 1:n_imagenes
    ruta_img = fullfile(carpeta_imagenes, nombres{i});
    imagenes{i} = imread(ruta_img);
end

%% Cambiar perspectiva

% puntos_actuales = [x, y];
puntos_actuales = [6.507500000000001e+02,82.249999999999770;1.307750000000000e+03,74.749999999999770;1.417250000000000e+03,8.607499999999999e+02;5.307500000000001e+02,8.697500000000000e+02];
 
% imshow(imagenes{1})
% puntos_actuales = ginput(4); 

close
ancho = 600; 
alto = 800;

% Arriba izq, arriba der, abajo der, abajo izq
puntos_destino = [1, 1; ancho, 1; ancho, alto; 1, alto];

% Calcular la transformación proyectiva
tform = fitgeotform2d(puntos_actuales, puntos_destino, 'projective');
R = imref2d([alto, ancho]);

% Aplicar la transformación a todas las imágenes
rect_imagenes = cell(n_imagenes, 1);
for i = 1:n_imagenes
    rect_imagenes{i} = imwarp(imagenes{i}, tform, 'OutputView', R);
end


%% Procesar imagen de reposo
img_gray_rep = im2gray(rect_imagenes{1});
img_double_rep = im2double(img_gray_rep);

% Realce de puntos oscuros con Bottom-Hat
enhanced_rep = imbothat(img_double_rep, strel('disk', 7));

% Binarización
T_rep = graythresh(enhanced_rep);
BW_rep = imbinarize(enhanced_rep, T_rep * 0.8);

% Limpieza morfológica
BW_rep = bwareaopen(BW_rep, 10);
BW_rep = imclose(BW_rep, strel('disk', 3));
BW_rep = imfill(BW_rep, 'holes');

% Extracción de objetos
stats_rep = regionprops(BW_rep, 'Area', 'Perimeter', 'Eccentricity', 'Centroid');
centers_rep = [];
for k = 1:length(stats_rep)
    A = stats_rep(k).Area;
    P = stats_rep(k).Perimeter;
    E = stats_rep(k).Eccentricity;
    if P == 0, continue; end

    %fórmula matemática estándar de la circularidad, un círculo perfecto dará 1
    circularity = 4 * pi * A / (P^2);

    if A >= 10 && circularity > 0.08 && E < 0.95
        centers_rep(end+1, :) = stats_rep(k).Centroid; %#ok<AGROW>
    end
end

% Primera pasada
% Contabilizar el número de puntos que se han detectado
N_rep = size(centers_rep, 1);
if N_rep < 10
    error('Muy pocos puntos detectados en la imagen de reposo'); 
end

% Distancia euclidiana entre todos los puntos
D_rep = pdist2(centers_rep, centers_rep);

% Los puntos cuya distancia es 0 significarán que son ellos mismos así que
%se sustituyen por inf para que el algoritmo no los coincida
D_rep(D_rep == 0) = Inf;

keep_rep = false(N_rep, 1);
for i = 1:N_rep
    dist = sort(D_rep(i, :)); %Ordena las distancias de menor a mayor
    vecinos = dist(1:min(8, length(dist))); %Se queda con los 8 vecinos mas cercanos que si es un punto de la malla deberían ser los que le rodean
    dLocal = median(vecinos); %Calcula la mediana de esos 8 puntos

    %Comprueba los vecinos que están a una distancia correcta.
    score = sum(vecinos > 0.5 * dLocal & vecinos < 1.8 * dLocal);

    %Si al menos tiene 5 vecinos correctos se guarda el punto.
    if score >= 5
        keep_rep(i) = true; 
    end

end
centers_rep = centers_rep(keep_rep, :);

% Fusión de duplicados
% Vuelve a calcular la distancia euclidiana de los puntos que han pasado
D_rep = pdist2(centers_rep, centers_rep);
D_rep(D_rep == 0) = Inf;

nearest_rep = min(D_rep, [], 2);    %Extra el vecino mas cercano
dMalla_rep = median(nearest_rep);   %Calcula de la mediana de la distancia a ese vecino

% Si la distancia al punto es <55% de la mediana se elimina
dFusion_rep = 0.55 * dMalla_rep;    
Adj_rep = D_rep < dFusion_rep;  %Matriz lógica indicando los puntos que están muy cerca
G_rep = graph(Adj_rep);         %Devuelve por parejas los índices de los puntos cercanos
cc_rep = conncomp(G_rep);       %Clasifica por grupos los índices de los puntos, asignando el mismo grupo si están cerca

newCenters_rep = [];
for k = 1:max(cc_rep)
    idx = find(cc_rep == k);    %Se buscan los puntos pertenecientes al mismo grupo
    %Se establece un solo punto en la media de sus centros
    x = mean(centers_rep(idx, 1));      
    y = mean(centers_rep(idx, 2));
    newCenters_rep(end+1, :) = [x, y]; %#ok<AGROW>
end
centers_rep = newCenters_rep;

% Segunda pasada pero guardando el punto con 4 vecinos correctos, en vez de 5
N_rep = size(centers_rep, 1);
D_rep = pdist2(centers_rep, centers_rep);
D_rep(D_rep == 0) = Inf;
keep_rep = false(N_rep, 1);
for i = 1:N_rep
    dist = sort(D_rep(i, :));
    vecinos = dist(1:min(8, length(dist)));
    dLocal = median(vecinos);
    score = sum(vecinos > 0.5 * dLocal & vecinos < 1.8 * dLocal);
    if score >= 4, keep_rep(i) = true; end
end
puntos_validos_rep = centers_rep(keep_rep, :);
fprintf('Puntos finales detectados en Reposo: %d\n', size(puntos_validos_rep, 1));


% Dibujar marcadores finales en reposo
figure( 'Color', 'w'); 
scatter(puntos_validos_rep(:,1), puntos_validos_rep(:,2), 35, 'k', 'filled');
axis equal; 
margen_visual = 50;
xlim([min(puntos_validos_rep(:,1)) - margen_visual, max(puntos_validos_rep(:,1)) + margen_visual]);
ylim([min(puntos_validos_rep(:,2)) - margen_visual, max(puntos_validos_rep(:,2)) + margen_visual]);
axis off;


% Calcular límites de malla fijos 
margen = 20;
x_min_fijo = min(puntos_validos_rep(:,1)) - margen;
x_max_fijo = max(puntos_validos_rep(:,1)) + margen;
y_min_fijo = min(puntos_validos_rep(:,2)) - margen;
y_max_fijo = max(puntos_validos_rep(:,2)) + margen;
[xq_fijo, yq_fijo] = meshgrid(x_min_fijo:5:x_max_fijo, y_min_fijo:5:y_max_fijo);

% Inicializar vectores de resultados
desplazamiento_total    = zeros(n_imagenes-1, 1);
marcadores_en_contacto  = zeros(n_imagenes-1, 1);
deformacion_media       = zeros(n_imagenes-1, 1);
entropia_valores        = zeros(n_imagenes-1, 1);
brillo_medio_contacto   = zeros(n_imagenes-1, 1);
brillo_maximo_contacto  = zeros(n_imagenes-1, 1);


%% Bucle de procesamiento de imágenes
for i = 2:n_imagenes
    % Convertir a gris e imdouble
    img_gray_desp = im2gray(rect_imagenes{i});
    img_double_desp = im2double(img_gray_desp);
    

    % Procesar imagen
    enhanced_desp = imbothat(img_double_desp, strel('disk', 7));
    T_desp = graythresh(enhanced_desp);
    BW_desp = imbinarize(enhanced_desp, T_desp * 0.8);
    
    BW_desp = bwareaopen(BW_desp, 10);
    BW_desp = imclose(BW_desp, strel('disk', 3));
    BW_desp = imfill(BW_desp, 'holes');
    
    stats_desp = regionprops(BW_desp, 'Area', 'Perimeter', 'Eccentricity', 'Centroid');
    centers_desp = [];
    for k = 1:length(stats_desp)
        A = stats_desp(k).Area;
        P = stats_desp(k).Perimeter;
        E = stats_desp(k).Eccentricity;
        if P == 0, continue; end
        circularity = 4 * pi * A / (P^2);
        if A >= 10 && circularity > 0.08 && E < 0.95
            centers_desp(end+1, :) = stats_desp(k).Centroid; %#ok<AGROW>
        end
    end
    
    % Primera pasada
    N_desp = size(centers_desp, 1);
    if N_desp >= 10
        D_desp = pdist2(centers_desp, centers_desp);
        D_desp(D_desp == 0) = Inf;
        keep_desp = false(N_desp, 1);
        for idx_c = 1:N_desp
            dist = sort(D_desp(idx_c, :));
            vecinos = dist(1:min(8, length(dist)));
            dLocal = median(vecinos);
            score = sum(vecinos > 0.5 * dLocal & vecinos < 1.8 * dLocal);
            if score >= 5, keep_desp(idx_c) = true; end
        end
        centers_desp = centers_desp(keep_desp, :);
        
        % Fusión de duplicados
        D_desp = pdist2(centers_desp, centers_desp);
        D_desp(D_desp == 0) = Inf;
        nearest_desp = min(D_desp, [], 2);
        dMalla_desp = median(nearest_desp);
        dFusion_desp = 0.55 * dMalla_desp;
        Adj_desp = D_desp < dFusion_desp;
        G_desp = graph(Adj_desp);
        cc_desp = conncomp(G_desp);
        newCenters_desp = [];
        for k = 1:max(cc_desp)
            idx = find(cc_desp == k);
            x = mean(centers_desp(idx, 1));
            y = mean(centers_desp(idx, 2));
            newCenters_desp(end+1, :) = [x, y]; %#ok<AGROW>
        end
        centers_desp = newCenters_desp;
        
        % Segunda pasada
        N_desp = size(centers_desp, 1);
        D_desp = pdist2(centers_desp, centers_desp);
        D_desp(D_desp == 0) = Inf;
        keep_desp = false(N_desp, 1);
        for idx_c = 1:N_desp
            dist = sort(D_desp(idx_c, :));
            vecinos = dist(1:min(8, length(dist)));
            dLocal = median(vecinos);
            score = sum(vecinos > 0.5 * dLocal & vecinos < 1.8 * dLocal);
            if score >= 4, keep_desp(idx_c) = true; end
        end
        puntos_validos_desp = centers_desp(keep_desp, :);
    else
        puntos_validos_desp = centers_desp;
    end
    
    %% Seguimiento KLT
    tracker = vision.PointTracker('MaxBidirectionalError', 2, 'BlockSize', [31 31]);
    initialize(tracker, puntos_validos_rep, img_gray_rep);
    [puntos_trackeados, validez] = step(tracker, img_gray_desp);
    release(tracker);
    
    % Almacenar solo los puntos rastreados con éxito
    puntos_rep_klt  = puntos_validos_rep(validez, :);
    puntos_desp_klt = puntos_trackeados(validez, :);
    
    % Vectores de desplazamiento
    x_rep = puntos_rep_klt(:, 1);
    y_rep = puntos_rep_klt(:, 2);
    x_desp = puntos_desp_klt(:, 1);
    y_desp = puntos_desp_klt(:, 2);
    
    % Calcular los vectores definitivos de desplazamiento
    u = x_desp - x_rep; 
    v = y_desp - y_rep; 
    distancia_pixel = sqrt(u.^2 + v.^2);
    
    %% Vía óptica: brillo en zona de contacto
    vq = griddata(x_rep, y_rep, distancia_pixel, xq_fijo, yq_fijo, 'cubic');
    
    % Máscara de contacto adaptativa
    umbral_contacto = max(3, 0.4 * max(vq(:))); 
    silueta = vq > umbral_contacto;
    silueta(isnan(silueta)) = 0; 
    
    % Redimensionar imagen de diferencia de brillo al tamaño de la malla
    diferencia_brillo = abs(double(img_gray_desp) - double(img_gray_rep));
    diferencia_brillo_redim = imresize(diferencia_brillo, size(vq));
    
    % Extraer brillo solo dentro de la zona de contacto
    brillo_contacto = diferencia_brillo_redim(silueta);
    if ~isempty(brillo_contacto)
        brillo_medio_contacto(i-1) = mean(brillo_contacto);
        brillo_maximo_contacto(i-1) = max(brillo_contacto);
    else
        brillo_medio_contacto(i-1) = 0;
        brillo_maximo_contacto(i-1) = 0;
    end
    
    %Ambos son cambios de brillo entre cada frame

    %% Vía mecánica
    desplazamiento_total(i-1)   = sum(distancia_pixel);
    marcadores_en_contacto(i-1) = sum(distancia_pixel > 1);
    
    if marcadores_en_contacto(i-1) > 0
        deformacion_media(i-1) = desplazamiento_total(i-1) / marcadores_en_contacto(i-1);
    end
    
    % Entropía
    [cuentas, ~] = histcounts(distancia_pixel, 15);
    p = cuentas / sum(cuentas);
    p(p == 0) = [];
    entropia_valores(i-1) = -sum(p .* log2(p));
    
    %% Representación gráfica
    mm_por_px_x = 40/ancho;
    mm_por_px_y = 50/alto;
    z_real_mm = tabla_recortada.Distance(i);

    %Se ponen los datos en una matriz de 2 columnas para poder compararlos
    puntos_malla = [xq_fijo(:), yq_fijo(:)];
    puntos_reales_frame = [x_rep, y_rep];

    [~, distancias_malla] = knnsearch(puntos_reales_frame, puntos_malla);

    %Vuelve a poner los resultados en una matriz de 2 columnas
    matriz_distancias = reshape(distancias_malla, size(xq_fijo)); 

    % Borrar la interpolación donde no hay puntos reales
    limite_hueco_px = 30; 
    vq(matriz_distancias > limite_hueco_px) = 0;
    vq(isnan(vq)) = 0;

    % Si el movimiento es nulo, evita la división por 0
    escalar_max = max(vq(:));
    if isempty(escalar_max) || escalar_max < 0.001
        divisor_seguro = 0.001;
    else
        divisor_seguro = escalar_max;
    end

    % Se normaliza la deformación entre 0 y 1
    vq_normalizado = vq ./ divisor_seguro;
    % Se multiplica la deformación por la penetración real para graficar
    % datos reales de hundimiento
    vq_mm = vq_normalizado .* z_real_mm;


end
%% Caracterización de fuerza del sensor

fuerza = tabla_recortada.Fuerza(2:end);

% Filtro para la vía mecánica
ratio_mecanico = fuerza ./ max(deformacion_media, 0.001); %Se hace así para evitar la división por 0
mediana_ratio_m = median(ratio_mecanico(deformacion_media > 0.5));

% Descartamos puntos que tengan una relación Fuerza/Deformación absurda
% Definimos los dos límites dinámicos
limite_superior_m = 4 * mediana_ratio_m;
limite_inferior_m = mediana_ratio_m / 4;
idx_validos_m = ratio_mecanico < limite_superior_m & ratio_mecanico > limite_inferior_m & deformacion_media > 0;

% Datos para vía mecánica
fuerza_val_m      = fuerza(idx_validos_m);
deformacion_val   = deformacion_media(idx_validos_m);

% Filtro para la vía óptica
% Filtrado exclusivo para Brillo Medio
ratio_fuerza_medio = fuerza ./ max(brillo_medio_contacto, 0.001);
mediana_ratio_medio = median(ratio_fuerza_medio(brillo_medio_contacto > 1));
idx_ok_medio = ratio_fuerza_medio < (4 * mediana_ratio_medio);
% Máscara definitiva para la regresión del Brillo Medio
idx_validos_o_medio = brillo_medio_contacto > 0 & idx_ok_medio;

% Filtrado exclusivo para Brillo Máximo
ratio_fuerza_max = fuerza ./ max(brillo_maximo_contacto, 0.001);
mediana_ratio_max = median(ratio_fuerza_max(brillo_maximo_contacto > 1));
idx_ok_max = ratio_fuerza_max < (4 * mediana_ratio_max);
% Máscara definitiva para la regresión del Brillo Máximo
idx_validos_o_maximo = brillo_maximo_contacto > 0 & idx_ok_max;

% Datos para la vía óptica de Brillo MEDIO
fuerza_val_o_medio = fuerza(idx_validos_o_medio);
brillo_medio_val   = brillo_medio_contacto(idx_validos_o_medio);

% Datos para la vía óptica de Brillo MÁXIMO
fuerza_val_o_maximo = fuerza(idx_validos_o_maximo);
brillo_maximo_val   = brillo_maximo_contacto(idx_validos_o_maximo);


%% Visualización de desplazamiento de los puntos junto con la topografía
figure('Name', 'Visualización de Desplazamientos y Topografía 3D', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 500]);
subplot(1, 2, 1);
imshow(rect_imagenes{i});  %Imagen de reposo
hold on;

% Se dibujan las flechas (quiver) que muestran el movimiento
% El '0' final es para que las flechas no se auto-escalen y se vea el tamaño real en píxeles
quiver(x_rep, y_rep, u, v, 0, 'Color', 'r', 'LineWidth', 1.5);
title('Vectores de Desplazamiento (Fuerza aplicada)');
hold off;

%Topografía 3D
subplot(1, 2, 2);
surf(xq_fijo*mm_por_px_x, yq_fijo*mm_por_px_y, vq_mm, 'EdgeColor', 'none'); 

colormap(gca, jet); 
clim([0, 3]);
zlim([0, 3]);

% Añadir barra de color específica para este subplot
barra_color = colorbar;
ylabel(barra_color, 'Hundimiento Z real (mm)');

shading interp;      % Suaviza los colores para que no se vean los píxeles cuadrados

% Configuración de iluminación y materiales
ax = gca;
ax.AmbientLightColor = [1 1 1];
camlight('left');    % Foco de luz virtual para el renderizado 3D
lighting gouraud;    % Calcula reflejos de luz realistas sobre la superficie
material dull;

title('Topografía 3D de la Presión en el Sensor', 'FontSize', 14);
xlabel('Eje X (mm)');
ylabel('Eje Y (mm)');
zlabel('Eje Z (mm)');

axis ij;             % Voltear el eje Y para mantener la orientación original de la foto
view(-35, 45);       % Girar la cámara en 3D 
axis equal;
grid on;



%% Análisis del autocurado. Contabilizar el área que se ha perdido en la raja
% Encontrar todas las celdas donde la altura en el surf sea 0
mascara_ceros_globales = (vq_mm == 0);

factor_X = 0.95; % Margen horizontal
factor_Y = 0.1; % Margen vertical

% Extraer el perímetro original
indices_contorno = convhull(puntos_reales_frame(:,1), puntos_reales_frame(:,2));
x_perimetro_px = puntos_reales_frame(indices_contorno, 1);
y_perimetro_px = puntos_reales_frame(indices_contorno, 2);

% Encontrar el centro del sensor
cx = mean(x_perimetro_px);
cy = mean(y_perimetro_px);

% Encoger los puntos hacia el centro aplicando el factor a cada eje
x_perimetro_nuevo_px = cx + (x_perimetro_px - cx) * factor_X;
y_perimetro_nuevo_px = cy + (y_perimetro_px - cy) * factor_Y;

% Evaluar qué celdas con Z=0 caen dentro de la línea magenta
esta_dentro_del_sensor = inpolygon(xq_fijo, yq_fijo, x_perimetro_nuevo_px, y_perimetro_nuevo_px);

mascara_ceros_interiores = mascara_ceros_globales & esta_dentro_del_sensor;

% Conteo final
num_puntos_negros_interiores = sum(mascara_ceros_interiores(:));
area_punto_negro_mm2 = num_puntos_negros_interiores * (5 * mm_por_px_x) * (5 * mm_por_px_y);
fprintf('Celdas negras interiores (inpolygon): %d (~%.2f mm²)\n',num_puntos_negros_interiores, area_punto_negro_mm2)

figure;
hold on;

% Gráfico de superficie
surf(xq_fijo*mm_por_px_x, yq_fijo*mm_por_px_y, vq_mm, 'EdgeColor', 'none'); 

colormap(gca, jet); 
clim([0, 3]);
zlim([0, 3]);

barra_color = colorbar;
ylabel(barra_color, 'Hundimiento Z real (mm)');

shading interp;      % Suaviza los colores para que no se vean los píxeles cuadrados

% Configuración de iluminación y materiales
ax = gca;
ax.AmbientLightColor = [1 1 1];
camlight('left');    % Foco de luz virtual para el renderizado 3D
lighting gouraud;    % Calcula reflejos de luz realistas sobre la superficie
material dull;

title('Comprobación del contorno creado', 'FontSize', 14);
xlabel('Eje X (mm)');
ylabel('Eje Y (mm)');
zlabel('Eje Z (mm)');

axis ij;             % Voltear el eje Y para mantener la orientación original de la foto
view(-35, 45);       % Girar la cámara en 3D 
axis equal;
grid on;



% Dibujar el contorno del sensor en la base (Z = 0)
if size(puntos_reales_frame, 1) >= 3
    % Pasar de píxeles a mm
    x_perimetro_mm = x_perimetro_nuevo_px * mm_por_px_x;
    y_perimetro_mm = y_perimetro_nuevo_px * mm_por_px_y;

    % Asegurar cerrar geométricamente el polígono 
    if ~isempty(x_perimetro_mm)
        x_perimetro_mm(end+1) = x_perimetro_mm(1);
        y_perimetro_mm(end+1) = y_perimetro_mm(1);
    end

    % Crer el vector de ceros a 3mm para poder visualizarla
    z_perimetro_mm = ones(size(x_perimetro_mm))*3;

    % Dibujar la línea perimetral 
    plot3(x_perimetro_mm, y_perimetro_mm, z_perimetro_mm, 'm-', 'LineWidth', 2.5);
end

% Buscar los índices de las celdas de la malla que son TRUE en la máscara
[filas_perdidas, columnas_perdidas] = find(mascara_ceros_interiores);

if ~isempty(filas_perdidas)
    % Extraer las coordenadas en píxeles de esas celdas específicas
    x_perdidas_px = xq_fijo(sub2ind(size(xq_fijo), filas_perdidas, columnas_perdidas));
    y_perdidas_px = yq_fijo(sub2ind(size(yq_fijo), filas_perdidas, columnas_perdidas));

    % Pasar a mm para que cuadren con la gráfica
    x_perdidas_mm = x_perdidas_px * mm_por_px_x;
    y_perdidas_mm = y_perdidas_px * mm_por_px_y;
    z_perdidas_mm = zeros(size(x_perdidas_mm)); % En el suelo de la gráfica

    % Dibujar las celdas en rojo
    plot3(x_perdidas_mm, y_perdidas_mm, z_perdidas_mm, 'r.', 'MarkerSize', 25);
end

hold off;


%% Análisis del autocurado. Cambio en el brillo para comprobar la raja

%Variación media acumulada del brillo (niveles de gris acumulados)
cambio_brillo_medio_total=sum(brillo_medio_contacto);

%Máximo pico alcanzado en todo el ensayo
cambio_brillo_maximo_total = max(brillo_maximo_contacto);

fprintf('Variación acumulada del brillo: %.2f \n', cambio_brillo_medio_total);
fprintf('Máximo pico de brillo: %.2f \n', cambio_brillo_maximo_total);

%% Calibración de las semiesferas blandas con el sensor
% Cambio en el brillo 
figure;
imshow(rect_imagenes{1});
hold on; 
silueta_escalada = imresize(silueta, [size(rect_imagenes{1},1), size(rect_imagenes{1},2)]);
h_silueta=imshow(silueta_escalada);
nivel_transparencia=0.4;
set(h_silueta, 'AlphaData', nivel_transparencia);
hold off;
title(sprintf('Br medio = %.2f -- Br max = %.2f',brillo_medio_contacto(end), brillo_maximo_contacto(end)))

% Radio en la zona de contacto

% Mostrar la última imagen tomada 
fig = figure('Name', 'Ajuste Manual de Círculo', 'NumberTitle', 'off');
imshow(rect_imagenes{end}); 
title({'Selección de la zona de contacto'});

% Crear el objeto del círculo de forma interactiva
roi = drawcircle();

% Esperar la confirmación del usuario
disp('Presionar cualquier tecla cuando el círculo esté ajustado');
tecla_presionada = 0;
while tecla_presionada == 0
    tecla_presionada = waitforbuttonpress;
end

% Extraer y mostrar los datos
radio_en_pixeles = roi.Radius;
fprintf('  Radio final ajustado : %.2f píxeles\n', radio_en_pixeles);

%% Deslizamiento entre dos cuerpos
tiempo = tabla_recortada.Time(2:end);
tiempo_valido = tiempo(idx_validos_m);


figure('Name', sufijo,'Position', [100, 200, 1000, 600]);
sgtitle(sufijo, 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');

subplot(2, 2, 1);
plot(tiempo,fuerza)
ylabel('Fuerza (N)')
xlabel('Tiempo (s)')
title('Gráfica dada por la Mecmesin')


subplot(2, 2, 2);
plot(deformacion_val, fuerza_val_m)
xlabel('Deformación media de los marcadores (píxeles)')
ylabel('Fuerza (N)')


subplot(2, 2, 3);
plot(tiempo_valido, deformacion_val)
ylabel('Deformación media de los marcadores (píxeles)')
xlabel('Tiempo (s)')


% Analisis firmeza uva

%diff calcula la diferencia entre elementos
%Si deformacion_val tiene N elementos, df tendrá N-1
df = diff(deformacion_val); 
df = lowpass(df, 0.4);

df_t = diff(tiempo_valido);
df_t = lowpass(df_t, 0.4);

df = df./df_t; %Cálculo de la derivada (pendiente) elemento a elemento
df(end + 1) = df(end); %Se duplica el último valor para tener el mismo tamaño

%Indica si la deformación es negativa o positiva
signos = sign(df);


cambios = diff(signos) ~= 0;    %Matriz lógica indicando el cambio de signo
indices_cambio = find(cambios); %Almacena los índices en los que se cambia de signo
texto_leyenda = sprintf('%d cambios detectados', sum(cambios));

subplot(2, 2, 4);
plot(tiempo_valido, df); % Grafica la línea original en azul
hold on;

%Dibujar puntos rojos en los momentos exactos del cambio de signo
plot(tiempo_valido(indices_cambio), df(indices_cambio), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5);

ylabel('Pendiente de la deformación (pixel/s)')
xlabel('Tiempo (s)')
title('Detección de Cambios de Signo en la Derivada')
grid on; % Añade cuadrícula para ver mejor los cruces por cero
legend(texto_leyenda)



%% Prueba de concepto con uvas reales
figure;
subplot(1,2,1)
plot(tiempo,fuerza)
ylabel('Fuerza (N)')
xlabel('Tiempo (s)')
title('Gráfica dada por la Mecmesin')

subplot(1,2,2)
plot(tiempo_valido, deformacion_val)
ylabel('Deformación media de los marcadores (píxeles)')
xlabel('Tiempo (s)')
title('Gráfica generada con el sensor')

sgtitle('Uva en buen estado')