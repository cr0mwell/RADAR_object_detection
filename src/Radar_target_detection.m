
%%%%%%%%%%%%%%%%%%%%%%
% VARIABLES DEFINITION
%%%%%%%%%%%%%%%%%%%%%%

c = 3e8;

% Radar specs 
radarFrequency = 77e9;	% GHz
radarMaxRange = 200;	% m
radarRangeRes = 1;	% m
radarMaxVelocity = 70; 	% m/s

% Target specs
startR = 65;	% Range to the target(m), should be in range (0;200)
V = 20;		% Target velocity(m/s), should be in range (-70;70)

% FMCW waveform
chirpBandwidth = c / (2*radarRangeRes);
chirpTime = 5.5*2*radarMaxRange / c;
chirpSlope = chirpBandwidth / chirpTime;

% The number of chirps in one sequence
Nd = 128;
% The number of sequences
Nr = 1024;
% Time sequence for running the displacement scenario for every sample on each chirp
t = linspace(0, Nd*chirpTime, Nr*Nd);

% Vectors for signals: Tx, Rx and Mix based on the total samples input
Tx = zeros(1, length(t));	%transmitted signal
Rx = zeros(1, length(t));	%received signal
Mix = zeros(1, length(t)); 	%beat signal

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SIGNAL GENERATION AND TARGET MOVING SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:length(t)         
    % Update the range to the target for constant velocity
    R(i) = startR + V*t(i);
    
    % Update the delay time
    tau(i) = 2*R(i)/c;
    
    % Update the transmitted and received signals
    Tx(i) = cos(2*pi*(radarFrequency*t(i) + chirpSlope*t(i)^2/2));
    Rx(i) = cos(2*pi*(radarFrequency*(t(i) - tau(i)) + chirpSlope*(t(i) - tau(i))^2/2));
    
    % Generate the beat signal
    %Mix(i) = cos(4*pi*(chirpSlope*R*t(i) + radarFrequency*V*tau)/c);
    Mix(i) = Tx(i).*Rx(i);
end

%%%%%%%%%%%%%%%%%%%
% RANGE MEASUREMENT
%%%%%%%%%%%%%%%%%%%
Mix = reshape(Mix, [Nr, Nd]);

% Fast Furier Transform
signalRange = fft(Mix, Nr);					% Running FFT along the Mix columns
signalRange = fftshift(signalRange, Nr);	% Normalizing
signalRange = abs(signalRange);				% Take the absolute value
signalRange = signalRange(1:Nr/2+1);		% Keep the half of the signal

% Plotting the range
figure ('Name', 'Range from FFT');
plot(signalRange);

%%%%%%%%%%%%%%%%%%%%
% DOPLER MEASUREMENT
%%%%%%%%%%%%%%%%%%%%

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr, Nd]);

% Apply 2D FFT
signal = fft2(Mix, Nr, Nd);

% Taking just one side of signal from Range dimension
signal = signal(1:Nr/2, 1:Nd);
signal = fftshift(signal);
signal = abs(signal);
signal = 10*log10(signal);

% Plot the output of 2D FFT
doppler_axis = linspace(-100, 100, Nd);
range_axis = linspace(-200, 200, Nr/2)*((Nr/2)/400);
figure ('Name', 'Dopler from 2D FFT');
surf(doppler_axis, range_axis, signal);

%%%%%%%%%%%%%%%%%%%%%%%%
% 2D-CFAR IMPLEMENTATION
%%%%%%%%%%%%%%%%%%%%%%%%

% Training cells
Tr = 8;
Td = 6;

% Guard cells
Gr = 4;
Gd = 2;

% Offset the threshold by SNR value in dB
offset = 7;

% Resulting array
result = zeros(size(signal));

% Sliding window for the signal
for i = Tr+Gr+1:Nr/2-Gr-Tr
    for j = Td+Gd+1:Nd-Gd-Td
    	noise_level = zeros(1,1);
    	for k = i-Gr-Tr:i+Gr+Tr
    	    for l = j-Gd-Td:j+Gd+Td
    	    	if (abs(i-k)>Gr || abs(j-l)>Gd)
    	   	    noise_level = noise_level + db2pow(signal(k, l));
    	   	end
    	    end 		
    	end
    	
    	% Calculating the threshold
    	threshold = pow2db(noise_level/((2*Td+2*Gd+1)*(2*Tr+2*Gr+1)-(2*Gr+1)*(2*Gd+1)));
    	
    	% Adding the offset
    	threshold = threshold + offset;
    	
    	test_cell = signal(i, j);
    	if (test_cell < threshold)
    	    result(i, j) = 0;
    	else
    	    m = sprintf("Setting (%d, %d) to 1!", i, j);
    	    disp(m);
    	    result(i, j) = 1;
    	end
    end
end

% Visualizing the result
figure('Name', 'Dopler after 2D CA-CFAR');
surf(doppler_axis, range_axis, result);
colorbar;
