%% Leer el excel con los datos de la mecmesin
clc; clear; close all

carpeta_datos = 'C:\Users\ALVARO\OneDrive - Universidad de Castilla-La Mancha\RobInd - AlvaroLabrada\Datos experimentos\Experimentos Alvaro';
dureza = 'Dureza_10_flex';
extension = '.csv';

ruta_excel = fullfile(carpeta_datos, [dureza, extension]);

fid = fopen(ruta_excel, 'r');
textscan(fid, '%s', 4, 'Delimiter', '\n'); % Saltar las 4 primeras líneas
raw = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', ''); % Leer el resto del archivo línea a línea como texto
fclose(fid);

texto = strrep(strjoin(raw{1}, '\n'), ',', '.'); % Unir todas las líneas y sustituir comas por puntos

datos = textscan(texto, '%f%f%f%*f', 'Delimiter', ';'); % Convertir las 3 primeras columnas a números (descartar la 4ª)
tabla_datos = table(datos{1}, datos{2}, datos{3}, 'VariableNames', {'Fuerza', 'Distance', 'Time'});

% Convertir tiempo de minutos a segundos
tabla_datos.Time = tabla_datos.Time * 60;

distancia=tabla_datos.Distance;
fuerza=tabla_datos.Fuerza;

figure;
plot(distancia,fuerza)
ylabel('Fuerza (N)')
xlabel('Distancia (mm)')
xlim([0,1])

%Se busca el índice donde se alcanza 1 mm de penetracion
diferencia = abs(distancia - 1); % Calcula la diferencia de todos los puntos y '1 mm'
distancia_minima = min(diferencia);% Encuentra cuál es la distancia mínima absoluta
fila = find(diferencia == distancia_minima);% Busca en qué fila se da esa distancia mínima

% Ajuste lineal
p = polyfit(distancia(1:fila(1)), fuerza(1:fila(1)), 1)
fitobject = fit(distancia(1:fila(1)),fuerza(1:fila(1)), 'a*x')

hold on;
plot(distancia, distancia*p(1) + p(2), 'r');
plot(distancia, distancia*fitobject.a, 'k');
legend('Gráfica original',sprintf('k polyfit = %.4f N/mm', p(1)),sprintf('k fit= %.4f N/mm', fitobject.a),'Location', 'northwest')
title(dureza, 'Interpreter', 'none');

%% Comprobación visual con la derivada

%diff calcula la diferencia entre elementos
df = diff(fuerza);
df = lowpass(df, 0.1);

df_d = diff(distancia);
df_d = lowpass(df_d, 0.1);

df = df./df_d;
df(end + 1) = df(end);

figure;
plot(distancia, df)
ylabel('Pendiente de la fuerza (N/mm)')
xlabel('Distancia (mm)')
xlim([0,3])
ylim([0 1.5])