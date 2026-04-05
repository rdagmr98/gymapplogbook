import os
import re

def check_project():
    print("--- INIZIO DIAGNOSTICA PROGETTO ---")
    
    # 1. Verifica Package Name in build.gradle
    gradle_path = "android/app/build.gradle.kts"
    app_id = ""
    if os.path.exists(gradle_path):
        with open(gradle_path, 'r') as f:
            content = f.read()
            match = re.search(r'applicationId\s*=\s*"([^"]+)"', content)
            if match:
                app_id = match.group(1)
                print(f"[OK] Application ID trovato: {app_id}")
    else:
        print("[ERRORE] build.gradle.kts non trovato!")

    # 2. Verifica Manifest e Permessi
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    required_permissions = [
        "SCHEDULE_EXACT_ALARM",
        "USE_EXACT_ALARM",
        "POST_NOTIFICATIONS",
        "VIBRATE"
    ]
    
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r') as f:
            content = f.read()
            # Controllo Package Name nel manifest
            manifest_pkg = re.search(r'package="([^"]+)"', content)
            if manifest_pkg and manifest_pkg.group(1) != app_id:
                print(f"[ATTENZIONE] Il package nel Manifest ({manifest_pkg.group(1)}) non coincide con applicationId!")
            
            for perm in required_permissions:
                if perm in content:
                    print(f"[OK] Permesso presente: {perm}")
                else:
                    print(f"[MANCANTE] Permesso critico: {perm}")
    
    # 3. Verifica Inizializzazione Main.dart
    main_path = "lib/main.dart"
    if os.path.exists(main_path):
        with open(main_path, 'r') as f:
            content = f.read()
            if "tz.initializeTimeZones()" not in content:
                print("[ERRORE] Timezone non inizializzate in main.dart")
            if "WidgetsFlutterBinding.ensureInitialized()" not in content:
                print("[ERRORE] WidgetsFlutterBinding mancante! L'app crasherà sicuramente.")

if __name__ == "__main__":
    check_project()