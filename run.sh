#!/bin/bash

# Đường dẫn tới tệp tin văn bản
file_path="Makefile"

# Đọc tệp tin và lấy các giá trị
while IFS=' =' read -r key value
do
  case $key in
    "VERSION")
      version=$value
      ;;
    "PATCHLEVEL")
      patchlevel=$value
      ;;
    "SUBLEVEL")
      sublevel=$value
      ;;
    "EXTRAVERSION")
      extraversion=$value
      ;;
  esac
done < "$file_path"

# Tạo chuỗi Linux version
linux_version="$version.$patchlevel.$sublevel$extraversion"

# In ra giá trị Linux version
echo "Linux: $linux_version"
