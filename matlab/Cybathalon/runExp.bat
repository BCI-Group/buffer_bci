call ..\..\utilities\findMatlab.bat
if %ismatlab%==1 (
  start "Matlab" /b %matexe% -r "runExp;quit;" %matopts%
) else (
  echo runExp;quit; | %matexe% %matopts%
)