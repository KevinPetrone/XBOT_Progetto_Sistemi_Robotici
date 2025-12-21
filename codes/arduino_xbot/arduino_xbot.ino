#include <Servo.h> //A,90,180,180
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// --- Servi ---
Servo s1, s2, sp;

// --- Oled --
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// --- Pin ---
#define BUZZER_PIN 3
const int PIN_S1 = 9;
const int PIN_S2 = 10;
const int PIN_SP = 11;

// Posizione corrente e target
float cur1 = 90, cur2 = 90, curp = 90;
float target1 = 90, target2 = 90, targetp = 90;

// Posizioni iniziali per interpolazione
float start1 = 90, start2 = 90, startp = 90;

// Timing per interpolazione
unsigned long moveStartMillis = 0;
const unsigned long moveDuration = 500; // tempo per completare il movimento in ms

// =============================================================
// --- OLED Helper ---
// --- Stato logo ---
bool logoShown = true;   // all'inizio sì

void Logo(){
  display.clearDisplay(); 
  display.setTextSize(2.5); 
  display.setTextColor(SSD1306_WHITE); 
  display.setCursor(10, 25); 
  display.println("XBOT v1.0"); display.display();
}

void showMessage(String msg, int x, int y, float z) {
  display.clearDisplay();
  display.setTextSize(z);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(x, y);
  display.println(msg);
  display.display();
}


// =============================================================
// --- Musiche ---
void playStartup() {
  int melody[] = {262, 294, 330, 392};
  int duration[] = {150, 150, 150, 300};
  for (int i = 0; i < 4; i++) {
    tone(BUZZER_PIN, melody[i], duration[i]);
    delay(duration[i] + 50);
  }
}

void playWin() {
  int melody[] = {392, 440, 494, 523, 494, 523, 587};
  int duration[] = {150, 150, 150, 200, 150, 200, 400};
  for (int i = 0; i < 7; i++) {
    tone(BUZZER_PIN, melody[i], duration[i]);
    delay(duration[i] + 30);
  }
}

void playGameOver() {
  // Note in Hz
  int melody[] = {165, 147, 131, 110}; // Mi3, Re3, Do3, La2
  int duration[] = {700, 700, 700, 1800}; // prime 3 lente, ultima molto lunga
  
  for (int i = 0; i < 4; i++) {
    tone(BUZZER_PIN, melody[i], duration[i]);
    delay(duration[i] + 100); // pausa tra le note
    noTone(BUZZER_PIN);
  }
}

void playMove() {
  tone(BUZZER_PIN, 440, 80);
  delay(100);
}

// =============================================================

void setup() {
  Serial.begin(115200);

  // OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    for (;;);
  }
  display.clearDisplay();
  Logo();  

  s1.attach(PIN_S1);
  s2.attach(PIN_S2);
  sp.attach(PIN_SP);

  // Imposta posizioni iniziali dei servo
  cur1 = 90;
  cur2 = 180;
  curp = 90;
  s1.write(cur1);
  s2.write(cur2);
  sp.write(curp);

 playStartup();   // Musica all'accensione

  // --- Comando iniziale A,90,180,90 ---
  start1 = cur1;
  start2 = cur2;
  startp = curp;

  target1 = 90;
  target2 = 180;
  targetp = 90;

  moveStartMillis = millis();
}

void loop() {
  // 1️⃣ Leggi seriale in modo non bloccante
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() > 0 && line.charAt(0) == 'A') {
      int a1=90, a2=180, ap=0;
      if (sscanf(line.c_str(),"A,%d,%d,%d",&a1,&a2,&ap) == 3) {
        start1 = cur1;
        start2 = cur2;
        startp = curp;

        target1 = constrain(a1, 0, 180);
        target2 = constrain(a2, 0, 180);
        targetp = constrain(ap, 0, 180);

        moveStartMillis = millis();
      }
    }
    else if (line.startsWith("MOVE")) {
      playMove();
    }
    else if (line.startsWith("WIN")) {
      playWin();
    }
    else if (line.startsWith("LOSE")) {
      playGameOver();
    }
    else if (line.startsWith("MSG,")) {
      // Trova le ultime 3 virgole
      int lastComma = line.lastIndexOf(',');
      int secondLast = line.lastIndexOf(',', lastComma - 1);
      int thirdLast = line.lastIndexOf(',', secondLast - 1);

      // Messaggio fino alla terza virgola
      String msg = line.substring(4, thirdLast);

      // Coordinate e dimensione
      int x = line.substring(thirdLast + 1, secondLast).toInt();
      int y = line.substring(secondLast + 1, lastComma).toInt();
      float z = line.substring(lastComma + 1).toInt();

      showMessage(msg, x, y, z);
    }
  }

  unsigned long now = millis();
  float t = float(now - moveStartMillis) / moveDuration;
  t = constrain(t, 0.0, 1.0); // Assicura che non si superi il 100%

  // Ottieni il fattore di movimento "curvato" dalla funzione
  float eased = easeInOut(t);

  // Calcola la nuova posizione interpolata
  // Formula: Posizione = Partenza + (DistanzaTotale * FattoreEased)
  cur1 = start1 + (target1 - start1) * eased;
  cur2 = start2 + (target2 - start2) * eased;
  curp = startp + (targetp - startp) * eased;

  // Invia il comando ai servomotori
  s1.write(round(cur1));
  s2.write(round(cur2));
  sp.write(round(curp));

  delay(10); // loop veloce ma non al massimo della CPU
}

// Funzione di easing in-out per movimento fluido
float easeInOut(float t) {
  // Se t < 0.5 (prima metà): Accelera con formula 2*t^2
  // Se t >= 0.5 (seconda metà): Decelera invertendo la parabola
  return t<0.5 ? 2*t*t : -1 + (4 - 2*t)*t;
}