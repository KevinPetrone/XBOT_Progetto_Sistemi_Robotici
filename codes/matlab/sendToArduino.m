function sendToArduino(s, th1, th2, z)
    % Invia i comandi di posizione ai servo reali
    % th1, th2 = angoli in radianti
    % z = quota simulata (0.05-0.8) → mappata in 180° (giù) ... -90° (su)

    if isempty(s) || ~isvalid(s)
        warning("⚠️ Arduino non connesso!");
        return;
    end

    % --- Angoli per i servomotori 1 e 2 ---
    a1 = round(90 + rad2deg(th1));  % servo 1 normale

    % Servo 2 invertito: 0 = S, 180 = N
    a2 = round(rad2deg(th2));       % da 0 a 180
    a2 = 180 - a2;                  % inversione

    % --- Servo penna ---
    z_min = 0.05; % penna giù
    z_max = 0.8;  % penna su
    servo3 = interp1([z_min z_max], [180 90], z, 'linear', 'extrap'); 

    % --- Clamping ---
    a1 = max(min(a1,180),0);
    a2 = max(min(a2,180),0);
    servo3 = max(min(servo3,190),90);

    % --- Invia comando ad Arduino ---
    cmd = sprintf("A,%d,%d,%d\n", a1, a2, round(servo3));
    writeline(s, cmd);
end
