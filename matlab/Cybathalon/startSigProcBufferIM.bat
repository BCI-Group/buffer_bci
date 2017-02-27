call ..\..\utilities\findMatlab.bat
if %ismatlab%==1 (
  start "Matlab" /b %matexe% -r "configureExp;imSigProcBufferIM('epochEventType','stimulus_im.target','freqband_im',freqband_im,'clsfr_type','ersp','trlen_ms',trlen_ms_im,'calibrateOpts',calibrateOpts_im,'trainOpts',trainOpts_im,'timeout_ms',timeout_ms,'verb',verb);quit;" %matopts%
) else (
echo configureExp;imSigProcBufferIM^('epochEventType','stimulus_im.target','freqband_im',freqband_im,'clsfr_type','ersp','trlen_ms',trlen_ms_im,'calibrateOpts',calibrateOpts_im,'trainOpts',trainOpts_im,'timeout_ms',timeout_ms,'verb',verb^);quit; | %matexe% %matopts%
)
