% Punti di test dalla relazione
test_points = [1.0, 1.0; 2.0, 1.5; 3.0, 2.0; 1.5, 2.5; 2.5, 3.0];
L1 = 2.5; L2 = 2.0;
errors = [];
fprintf('--- INIZIO TEST DI VALIDAZIONE ---\n');
for i = 1:size(test_points, 1)
    x_target = test_points(i, 1);
    y_target = test_points(i, 2);   
    % 1. Calcolo Cinematica Inversa (IK)
    [th1, th2, valid] = local_safeIK2R(x_target, y_target, L1, L2);
    if ~valid
        fprintf('Punto (%f, %f) non raggiungibile\n', x_target, y_target);
        continue;
    end   
    % 2. Calcolo Cinematica Diretta (FK) per verifica
    x_calc = L1*cos(th1) + L2*cos(th1+th2);
    y_calc = L1*sin(th1) + L2*sin(th1+th2);
    % 3. Calcolo Errore
    err = sqrt((x_calc-x_target)^2 + (y_calc-y_target)^2);
    errors = [errors; err];  
    fprintf('Target: (%.1f, %.1f) -> Calc: (%.1f, %.1f) | Errore: %e mm\n', ...
        x_target, y_target, x_calc, y_calc, err*1000);
end
fprintf('\n--- RISULTATI ---\n');
fprintf('Errore medio: %e mm\n', mean(errors)*1000);
fprintf('Errore max:   %e mm\n', max(errors)*1000);
% --- Funzione Cinematica Inversa (copiata dal tuo codice) ---
function [th1, th2, valid] = local_safeIK2R(x, y, L1, L2)
    r = sqrt(x^2 + y^2);
    if r > (L1 + L2) || r < abs(L1-L2), th1=0; th2=0; valid=false; return; end
    cos_th2 = (x^2 + y^2 - L1^2 - L2^2)/(2*L1*L2);
    cos_th2 = max(min(cos_th2,1),-1);
    sin_th2 = sqrt(max(0,1-cos_th2^2));
    th2 = atan2(sin_th2, cos_th2);
    k1 = L1 + L2*cos_th2; k2 = L2*sin_th2;
    th1 = atan2(y,x)-atan2(k2,k1);
    valid = true;
end




