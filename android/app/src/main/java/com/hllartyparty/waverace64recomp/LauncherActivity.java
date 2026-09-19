package com.hllartyparty.waverace64recomp;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.security.*;

public final class LauncherActivity extends Activity {
    private static final int PICK_ROM = 1001;
    private static final String EXPECTED = "508dfc2d4caa42b6f6de5263d0aed5e44ac7966a";
    private TextView status;

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        LinearLayout box = new LinearLayout(this); box.setOrientation(LinearLayout.VERTICAL); box.setPadding(48,48,48,48);
        TextView title = new TextView(this); title.setText("Wave Race 64 Recompiled"); title.setTextSize(26);
        status = new TextView(this); status.setText("Select your legally obtained Wave Race 64 (USA) Rev A ROM."); status.setPadding(0,24,0,24);
        Button pick = new Button(this); pick.setText("Select ROM"); pick.setOnClickListener(v -> pickRom());
        box.addView(title); box.addView(status); box.addView(pick); setContentView(box);
        File installed = new File(getFilesDir(), "waverace_revA.z64");
        if (installed.isFile()) launch(installed);
    }

    private void pickRom() {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT); i.addCategory(Intent.CATEGORY_OPENABLE); i.setType("*/*");
        startActivityForResult(i, PICK_ROM);
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != PICK_ROM || result != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData(); status.setText("Checking ROM…");
        new Thread(() -> {
            try {
                byte[] raw; try (InputStream in = getContentResolver().openInputStream(uri); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                    byte[] buf = new byte[65536]; for (int n; (n=in.read(buf))>0;) out.write(buf,0,n); raw=out.toByteArray();
                }
                byte[] z64 = normalize(raw); String sha = sha1(z64);
                if (!EXPECTED.equalsIgnoreCase(sha)) throw new IOException("Wrong ROM revision. SHA-1: " + sha);
                File dest = new File(getFilesDir(), "waverace_revA.z64"); try(FileOutputStream out = new FileOutputStream(dest)){ out.write(z64); }
                runOnUiThread(() -> launch(dest));
            } catch (Exception e) { runOnUiThread(() -> status.setText("ROM rejected: " + e.getMessage())); }
        }).start();
    }

    private byte[] normalize(byte[] d) throws IOException {
        if (d.length < 4) throw new IOException("File is too small");
        int m=((d[0]&255)<<24)|((d[1]&255)<<16)|((d[2]&255)<<8)|(d[3]&255);
        if (m==0x80371240) return d;
        byte[] o=new byte[d.length];
        if (m==0x37804012) { for(int i=0;i+1<d.length;i+=2){o[i]=d[i+1];o[i+1]=d[i];} return o; }
        if (m==0x40123780) { for(int i=0;i+3<d.length;i+=4){o[i]=d[i+3];o[i+1]=d[i+2];o[i+2]=d[i+1];o[i+3]=d[i];} return o; }
        throw new IOException("Unknown N64 byte order");
    }
    private String sha1(byte[] d) throws Exception { byte[] h=MessageDigest.getInstance("SHA-1").digest(d); StringBuilder s=new StringBuilder(); for(byte b:h)s.append(String.format("%02x",b)); return s.toString(); }
    private void launch(File rom){ Intent i=new Intent(this,GameActivity.class); i.putExtra("rom",rom.getAbsolutePath()); startActivity(i); finish(); }
}
