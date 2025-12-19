function tris_robotics_game()
% TRIS ROBOTICO INTERATTIVO - versione intelligente con Arduino

    clc; close all; clear;
    cd(fileparts(mfilename('fullpath'))); rehash;
    
    %% --- Connessione Arduino ---
    s = initArduino("COM4"); % 🔧 Cambia COM4 con la porta corretta

    %% --- Robot (parametri cinematica) ---
    L1 = Link('d',0,'a',2.5,'alpha',0);
    L2 = Link('d',0,'a',2.0,'alpha',0);
    L3 = Link('theta',0,'a',0,'alpha',pi/2,'prismatic','qlim',[0 1]);
    robot = SerialLink([L1 L2 L3],'name','3R_DrawBot');

    %% --- Workspace e grafica ---
    workspace = [-1 5 -3 5 -0.5 1.5];
    figure('Color','w','Position',[200 100 900 700]);
    axis(workspace); hold on; grid on; axis equal;
    view(0,90); xlabel('X'); ylabel('Y');
    title('Tris Robotico Interattivo');
    robot.plot([0 0 0.8],'workspace',workspace,'delay',0.01); drawnow;

    ik2R = @(x,y) safeIK2R(x,y,L1.a,L2.a);

    %% --- Video ---
    v = VideoWriter('tris_robotico_gioco.avi'); v.FrameRate = 25; open(v);

    %% --- Griglia ---
    cellSize = 0.9; offset = 0.6;
    gridSize = 3*cellSize;
    x0 = offset; y0 = offset;
    x1 = x0 + cellSize; x2 = x0 + 2*cellSize;
    y1 = y0 + cellSize; y2 = y0 + 2*cellSize;

    disp('Disegno griglia...');
    msg = "DISEGNO   GRIGLIA..";
    cmd = sprintf("MSG,%s,20,25,2\n", msg);  %s per la stringa
    writeline(s, cmd);
    drawLine(robot, ik2R, v, s, x1, y0, x1, y0+gridSize);
    drawLine(robot, ik2R, v, s, x2, y0, x2, y0+gridSize);
    drawLine(robot, ik2R, v, s, x0, y1, x0+gridSize, y1);
    drawLine(robot, ik2R, v, s, x0, y2, x0+gridSize, y2);

    %% --- Centri celle ---
    centers = [
        x0 + cellSize/2, y0 + 2*cellSize + cellSize/2; % 1
        x0 + 1.5*cellSize, y0 + 2*cellSize + cellSize/2; % 2
        x0 + 2.5*cellSize, y0 + 2*cellSize + cellSize/2; % 3
        x0 + cellSize/2, y0 + 1*cellSize + cellSize/2; % 4
        x0 + 1.5*cellSize, y0 + 1*cellSize + cellSize/2; % 5
        x0 + 2.5*cellSize, y0 + 1*cellSize + cellSize/2; % 6
        x0 + cellSize/2, y0 + 0*cellSize + cellSize/2; % 7
        x0 + 1.5*cellSize, y0 + 0*cellSize + cellSize/2; % 8
        x0 + 2.5*cellSize, y0 + 0*cellSize + cellSize/2; % 9
    ];

    %% --- Setup gioco ---
    board = repmat(' ',3,3);
    symbols = ['X','O'];
    writeline(s, "MOVE"); % 🔊 suono cambio turno
    msg = "   SCEGLI    X o O?";
    cmd = sprintf("MSG,%s,0,0,2\n", msg);  %s per la stringa
    writeline(s, cmd);

    user_symbol = upper(input('Vuoi essere X o O? ','s'));
    while ~ismember(user_symbol,symbols)
        user_symbol = upper(input('Scelta non valida. Vuoi essere X o O? ','s'));
    end
    robot_symbol = setdiff(symbols,user_symbol);
    fprintf('Tu sei %s, il robot è %s.\n',user_symbol,robot_symbol);
    msg = "    SEI       ";
    cmd = sprintf("MSG,%s %s,0,2,2\n", msg, user_symbol);  %s per la stringa
    writeline(s, cmd);
    pause(3);  % aspetta 3 secondi

    turn = 'user'; moves = 0; winner = ' ';

    %% --- Ciclo di gioco ---
    while winner == ' ' && moves < 9
        if strcmp(turn,'user')
            writeline(s, "MOVE"); % 🔊 suono cambio turno
            msg = " E' il tuo  turno!!";
            cmd = sprintf("MSG,%s,0,20,2\n", msg);  %s per la stringa
            writeline(s, cmd);
            cell_num = input("E' il tuo turno. Scegli una cella (1-9):");
            while ~ismember(cell_num,1:9) || board(cellRow(cell_num),cellCol(cell_num))~=' '
                cell_num = input('Cella occupata o invalida. Scegli un''altra (1-9): ');
            end
            board(cellRow(cell_num),cellCol(cell_num)) = user_symbol;
            drawSymbol(robot, ik2R, v, s, centers(cell_num,:), user_symbol);
            moves = moves + 1;
            winner = checkWinner(board);
            turn = 'robot';
        else
            free_cells = find(board==' ');
            if isempty(free_cells), break; end

            % --- Robot intelligente ---
            cell_num = findBestMove(board, robot_symbol); % prova a vincere
            if cell_num == 0
                cell_num = findBestMove(board, user_symbol); % blocca utente
                if cell_num == 0
                    % centro libero
                    if board(2,2) == ' ', cell_num=5; else cell_num=free_cells(randi(length(free_cells))); end
                end
            end
            writeline(s, "MOVE"); % 🔊 suono cambio turno
            fprintf('🤖 Il robot sceglie la cella %d\n',cell_num);
            msg = " E' il mio  turno :)";
            cmd = sprintf("MSG,%s,0,20,2\n", msg);  %s per la stringa
            writeline(s, cmd);
            board(cellRow(cell_num),cellCol(cell_num)) = robot_symbol;
            drawSymbol(robot, ik2R, v, s, centers(cell_num,:), robot_symbol);
            moves = moves + 1;
            winner = checkWinner(board);
            turn = 'user';
        end
    end

    %% --- Esito ---
    if winner == ' '
        disp('🤝 Pareggio!');
        for l = 1:3
            msg = "Pareggio!";
            scrollMsg(msg, s, 0, 0, 2, 19, 0.3, 2);
            pause(2); 
            msg = "Giochiamo ancora!";
            scrollMsg(msg, s, 0, 0, 2, 19, 0.3, 2);
            pause(2); 
        end
    elseif winner == user_symbol
        %% 🎉 VITTORIA UTENTE
        disp('🏆 Hai vinto!');
        msg = "HAI VINTO!";
        cmd = sprintf("MSG,%s,8,0,2\n", msg);
        writeline(s, cmd);
    
        writeline(s, "WIN");   % Arduino suona
        pause(0.70);  % aspetta metà musica WIN
    
        % Frasi WIN (positive e un po' "cattive")
        winPhrases = [
            "Ok... bravo... per questa volta!"
            "Non male umano, NON male!"
            "Hai vinto?! Aspetta devo ricalibrare i servi."
            "Va bene, oggi sei fortunato..."
            "Che botta di fortuna, wow!"
            "Uff... mi hai battuto!"
            "Lo ammetto: questa mi ha sorpreso!"
            "Goditela, non succedera' spesso!"
            "Hai vinto... NON ci credo."
            "Bravo! Ma solo un po'."
        ];
    
        idx = randi(numel(winPhrases));
        scrollMsg(winPhrases(idx), s, 0, 0, 1, 19, 0.3, 2);
        drawWinningLine(robot, ik2R, v, s, winner, board, centers);
    else
        %% 🤖 SCONFITTA UTENTE
        disp('🤖 Il robot ha vinto!');
        msg = "HAI PERSO!";
        cmd = sprintf("MSG,%s,8,0,2\n", msg);
        writeline(s, cmd);
    
        writeline(s, "LOSE");  % Arduino suona
        pause(0.60); % aspetta musica LOSE
    
        % Frasi LOSE (più cattive)
        losePhrases = [
            "Scarsino. Ritenta."
            "Non eri pronto per me."
            "Facile. Troppo facile."
            "Umano troppo lento!"
            "Sei sicuro di aver capito le regole?"
            "KO... che pena!"
            "Mi sto annoiando!"
            "Serve piu' di questo per battermi."
            "Io vinco. Punto."
            "Voglio piu' sfida!"
        ];
    
        idx = randi(numel(losePhrases));
        scrollMsg(losePhrases(idx), s, 0, 0, 1, 19, 0.3, 2);
        drawWinningLine(robot, ik2R, v, s, winner, board, centers);
    end

    close(v);
    disp('🎬 Video salvato come tris_robotico_gioco.avi');
end

%% --- Funzione scroll avanti/indietro ---
function scrollMsg(msg, s, x, y, page, max_len, pause_time, loops)
    msg = char(msg);
    L = strlength(msg);

    if L <= max_len
        cmd = sprintf("MSG,%s,%d,%d,%d\n", msg, x, y, page);
        writeline(s, cmd);
        return;
    end

    for l = 1:loops
        % avanti
        for idx = 1:(L - max_len + 1)
            part = msg(idx:idx+max_len-1);
            cmd = sprintf("MSG,%s,%d,%d,%d\n", part, x, y, page);
            writeline(s, cmd);
            pause(pause_time);
        end
        % indietro
        for idx = (L - max_len):-1:1
            part = msg(idx:idx+max_len-1);
            cmd = sprintf("MSG,%s,%d,%d,%d\n", part, x, y, page);
            writeline(s, cmd);
            pause(pause_time);
        end
    end

    % mostra ultima parte completa
    part = msg(end-max_len+1:end);
    cmd = sprintf("MSG,%s,%d,%d,%d\n", part, x, y, page);
    writeline(s, cmd);
end

%% --- Funzioni di supporto ---

function [th1, th2, valid] = safeIK2R(x, y, L1, L2)
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

function r = cellRow(c), r = 4 - ceil(c/3); end
function c = cellCol(c), c = mod(c-1,3)+1; end

function winner = checkWinner(b)
    winner = ' ';
    lines = [1 2 3; 4 5 6; 7 8 9; 1 4 7; 2 5 8; 3 6 9; 1 5 9; 3 5 7];
    for i=1:size(lines,1)
        l = lines(i,:);
        vals = [b(cellRow(l(1)),cellCol(l(1))), b(cellRow(l(2)),cellCol(l(2))), b(cellRow(l(3)),cellCol(l(3)))];
        if all(vals=='X'), winner='X'; return;
        elseif all(vals=='O'), winner='O'; return;
        end
    end
end

function best = findBestMove(board, symbol)
    best=0;
    lines = [1 2 3; 4 5 6; 7 8 9; 1 4 7; 2 5 8; 3 6 9; 1 5 9; 3 5 7];
    for i=1:size(lines,1)
        l = lines(i,:);
        vals = [board(cellRow(l(1)),cellCol(l(1))), board(cellRow(l(2)),cellCol(l(2))), board(cellRow(l(3)),cellCol(l(3)))];
        if sum(vals==symbol)==2 && sum(vals==' ')==1
            idx = find(vals==' ');
            best = l(idx);
            return;
        end
    end
end

%% --- Funzioni di disegno robot ---
function movePen(robot, ik2R, v, s, x1, y1, z1, x2, y2, z2)
    n=40; xs=linspace(x1,x2,n); ys=linspace(y1,y2,n); zs=linspace(z1,z2,n);
    for i=1:n
        [th1,th2,ok]=ik2R(xs(i),ys(i)); if ~ok, continue; end
        q=[th1 th2 zs(i)];
        sendToArduino(s, q(1), q(2), q(3));
        robot.plot(q,'delay',0.002,'workspace',[-1 5 -1 5 -0.5 1.5]);
        frame=getframe(gca); frame.cdata=imresize(frame.cdata,[525 700]);
        writeVideo(v,frame);
    end
end

function drawLine(robot, ik2R, v, s, x1, y1, x2, y2)
    persistent currPos; if isempty(currPos), currPos=[x1,y1,0.8]; end
    z_up=0.8; z_down=0.05;
    movePen(robot, ik2R, v, s, currPos(1),currPos(2),currPos(3),x1,y1,z_up);
    movePen(robot, ik2R, v, s, x1,y1,z_up,x1,y1,z_down);
    n=50; xs=linspace(x1,x2,n); ys=linspace(y1,y2,n);
    for i=1:n
        [th1,th2,ok]=ik2R(xs(i),ys(i)); if ~ok,continue;end
        q=[th1 th2 z_down];
        sendToArduino(s, q(1), q(2), q(3));
        robot.plot(q,'delay',0.002);
        plot3(xs(1:i),ys(1:i),zeros(1,i),'k','LineWidth',2);
        frame=getframe(gca); frame.cdata=imresize(frame.cdata,[525 700]); 
        writeVideo(v,frame);
    end
    movePen(robot, ik2R, v, s, x2,y2,z_down,x2,y2,z_up);
    currPos=[x2,y2,z_up];
end

function drawSymbol(robot, ik2R, v, s, pos, symbol)
    cx=pos(1); cy=pos(2); sdim=0.35; z_up=0.8; z_down=0.05;
    persistent currPos; if isempty(currPos), currPos=[cx cy z_up]; end
    movePen(robot, ik2R, v, s, currPos(1),currPos(2),currPos(3),cx,cy,z_up);

    if symbol=='X'
        th=linspace(0,1,40);
        % Prima diagonale
        x1=cx-sdim; y1=cy-sdim; x2=cx+sdim; y2=cy+sdim;
        movePen(robot,ik2R,v,s,cx,cy,z_up,x1,y1,z_down);
        for t=th
            x=x1+(x2-x1)*t; y=y1+(y2-y1)*t;
            [th1,th2,ok]=ik2R(x,y); if ~ok, continue; end
            q=[th1 th2 z_down]; sendToArduino(s,q(1),q(2),q(3));
            robot.plot(q,'delay',0.002); plot3(x,y,0,'r.','MarkerSize',10);
        end
        movePen(robot,ik2R,v,s,x2,y2,z_down,x2,y2,z_up);

        % Seconda diagonale
        x1=cx-sdim; y1=cy+sdim; x2=cx+sdim; y2=cy-sdim;
        movePen(robot,ik2R,v,s,x1,y1,z_up,x1,y1,z_down);
        for t=th
            x=x1+(x2-x1)*t; y=y1+(y2-y1)*t;
            [th1,th2,ok]=ik2R(x,y); if ~ok, continue; end
            q=[th1 th2 z_down]; sendToArduino(s,q(1),q(2),q(3));
            robot.plot(q,'delay',0.002); plot3(x,y,0,'r.','MarkerSize',10);
        end
        movePen(robot,ik2R,v,s,x2,y2,z_down,x2,y2,z_up);
    else
        th = linspace(0,2*pi,80);
        x = cx + sdim*cos(th); y = cy + sdim*sin(th);
        movePen(robot, ik2R, v, s, cx,cy,z_up,x(1),y(1),z_down);
        for i=1:length(th)
            [th1,th2,ok]=ik2R(x(i),y(i)); if ~ok, continue; end
            q=[th1 th2 z_down]; sendToArduino(s,q(1),q(2),q(3));
            robot.plot(q,'delay',0.002); plot3(x(i),y(i),0,'b.','MarkerSize',10);
        end
        movePen(robot, ik2R, v, s, x(end),y(end),z_down,x(end),y(end),z_up);
    end
    currPos=[cx,cy,z_up];
end

function drawWinningLine(robot, ik2R, v, s, winner, board, centers)
    lines = [1 2 3; 4 5 6; 7 8 9; 1 4 7; 2 5 8; 3 6 9; 1 5 9; 3 5 7];
    for i=1:size(lines,1)
        l = lines(i,:);
        vals = [board(cellRow(l(1)),cellCol(l(1))), board(cellRow(l(2)),cellCol(l(2))), board(cellRow(l(3)),cellCol(l(3)))];
        if all(vals==winner)
            p1 = centers(l(1),:); p3 = centers(l(3),:);
            drawLine(robot, ik2R, v, s, p1(1),p1(2),p3(1),p3(2));
            break;
        end
    end
end