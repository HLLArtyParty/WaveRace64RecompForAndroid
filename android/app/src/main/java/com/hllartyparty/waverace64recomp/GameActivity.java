package com.hllartyparty.waverace64recomp;

import android.os.*;
import android.view.*;
import org.libsdl.app.SDLActivity;
import java.io.*;

public final class GameActivity extends SDLActivity {
    @Override protected String[] getLibraries(){ return new String[]{"SDL2","WaveRace64Recomp"}; }
    @Override protected String[] getArguments(){
        String rom=getIntent().getStringExtra("rom");
        File program=new File(getFilesDir(),"program");
        return new String[]{rom, "--android-data-dir="+getFilesDir().getAbsolutePath(), "--android-program-dir="+program.getAbsolutePath()};
    }
    @Override protected void onCreate(Bundle b){
        try { copyAssetTree("program", new File(getFilesDir(),"program")); } catch(Exception ignored){}
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }
    private void copyAssetTree(String asset, File out) throws IOException {
        String[] kids=getAssets().list(asset);
        if(kids==null||kids.length==0){ File p=out.getParentFile(); if(p!=null)p.mkdirs(); try(InputStream in=getAssets().open(asset); OutputStream o=new FileOutputStream(out)){byte[]b=new byte[65536];for(int n;(n=in.read(b))>0;)o.write(b,0,n);} return; }
        out.mkdirs(); for(String k:kids)copyAssetTree(asset+"/"+k,new File(out,k));
    }
}
