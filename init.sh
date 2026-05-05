#!/bin/bash
export PATH="$PATH:$HOME/.flutter/bin"
cd "/mnt/d/Fallah's File/Code/Personal Project/WorthIt"
flutter create worthit_app
cd worthit_app
flutter pub add google_fonts fl_chart camera google_mlkit_text_recognition
