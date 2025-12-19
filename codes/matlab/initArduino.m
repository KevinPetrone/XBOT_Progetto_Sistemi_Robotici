function s = initArduino(port)
    % Inizializza la connessione seriale con Arduino
    if nargin < 1, port = "COM4"; end
    disp("🔌 Connessione ad Arduino su " + port + " ...");

    try
        s = serialport(port,115200);
        configureTerminator(s,"LF");
        pause(1.0);
        flush(s);
        writeline(s,"A,90,180,90"); % posizione iniziale
        disp("✅ Arduino inizializzato su " + port);
    catch ME
        warning("❌ Errore connessione Arduino: " + ME.message);
        s = [];
    end
end