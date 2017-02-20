#!/bin/bash
cd `dirname ${BASH_SOURCE[0]}`
source ../../utilities/findMatlab.sh
if [[ $matexe == *matlab ]]; then  args=-nodesktop; fi
cat <<EOF | $matexe $args
configureExp;
imSigProcBufferIM('epochEventType','stimulus_im.target','freqband_im',[6 8 28 30],...
                   'clsfr_type','ersp','trlen_ms',trlen_ms,...
                   'calibrateOpts',calibrateOpts,'trainOpts',trainOpts);
%quit;
EOF
