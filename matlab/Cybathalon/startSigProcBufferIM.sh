#!/bin/bash
cd `dirname ${BASH_SOURCE[0]}`
source ../../utilities/findMatlab.sh
if [[ $matexe == *matlab ]]; then  args=-nodesktop; fi
cat <<EOF | $matexe $args
configureExp;
imSigProcBufferIM('epochEventType','stimulus_im.target','freqband_im',freqband_im,...
                   'clsfr_type','ersp','trlen_ms',trlen_ms_im,...
                   'calibrateOpts',calibrateOpts_im,'trainOpts',trainOpts_im,'timeout_ms',timeout_ms,'verb',verb);
%quit;
EOF
