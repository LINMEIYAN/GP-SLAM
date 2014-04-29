% =========================================================================
%       ---------------------------------------------------------
%        Test the effect of Tetha and its convergance properties
%       ---------------------------------------------------------
% Authour : Mahdi Jadaliha
% e-mail  : jadaliha@gmail.com
% =========================================================================
%tic  
close all
clear all
clc
global globaloption  sys_parameter
%----- initialize system configuration-------------------------------------
[ globaloption , sys_parameter ] = Configuration();
option = globaloption;

%%% Case 1: Generate data
%----- generate or load the field------------------------------------------
% [true_field, VehicleStates, AgumentedData, ~]  =  ...                       % [field, VehicleStates, AgumentedData, numberofpossibilities] = Generate_new_field(savetofile)
%     Generate_new_field();                                                   % the data will be saved in 'savetofile'


%%% Case 2: Load data
importxls                                                                   % Load the excel sheet
load polishedFeature T
%load unFilteredFeature feature
%load data %for loading data quickly
%noiseMagnitude=30;
noiseStd=60;
restricted=400;
scaleRatio=10;  
location = [downSampling(locationX(1:restricted),scaleRatio),...
    downSampling(locationY(1:restricted),scaleRatio)];    % Assign the Location
dataSize=size(location,1);
% noiseAdded=ones(dataSize,1)*mean(mean(location))+noiseStd*randn(dataSize,1);
noiseAddedX=noiseStd*randn(dataSize,1);
noiseAddedY=noiseStd*randn(dataSize,1);
noiseAddedX=noiseAddedX-mean(noiseAddedX);
noiseAddedY=noiseAddedY-mean(noiseAddedY);

%noiseStd=sqrt(var(noiseAdded));
% location_noise=[downSampling(locationX(1:restricted),scaleRatio)+noiseAdded,...
%                 downSampling(locationY(1:restricted),scaleRatio)+noiseAdded];
location_noise=[downSampling(locationX(1:restricted),scaleRatio)+noiseAddedX,...
                downSampling(locationY(1:restricted),scaleRatio)+noiseAddedY];
%location_noise(3:end,:)=location_noise(3:end,:)+[noiseAddedX(3:end),noiseAddedY(3:end)];

%features = downSampling(HIST10(1:restricted),scaleRatio);                                                           % select the one or more features
%features = downSampling(feature(1:restricted),scaleRatio); 
features = downSampling(T(1:restricted),scaleRatio); 
%---- we normalize features here
features = features - ones(size(features,1),1)*mean(features,1);            % remove mean average
cov_features = cov(features);
[U,S,~] =  svd(cov_features);                                               % make feature orthogonal using SVD 
features = features*U*sqrt(S^-1);                                           %transfer top new coordinates
%---- Predict hyper parameters
nf = size(features,2);
hyper_p = zeros(4,nf);
for index = 1:nf
    f = features(:,index);
    p0 = [var(f) 3 3 0.5]'; % sig_f^2, sig_x sig_y sigma2w                  % Initial guess of hyper-parameters
    %p0 = [1 350 300 0.3]'; % sig_f^2, sig_x sig_y sigma2w                  % Initial guess of hyper-parameters
   % [hyper_p(:,index), ~] = HyperParameter(f,location(:,1:2), p0);          % extract hyper parameters for each layer sepratly
    hyper_p(:,index) = [0.69;5;5;0.22];    %[0.69;5;5;0.22] [1.7;5;5;0.22]
    str = sprintf('hyper-parameters # %d: \t (sig_f^2: %0.2f, \t sig_x: %0.2f, \t sig_y: %0.2f, \t sig_w^2: %0.2f)',index,hyper_p(1,index),hyper_p(2,index),hyper_p(3,index),hyper_p(4,index));
    disp(str)
end

% Normalize coordinate and compute Precision hyperparameters from GP
% hyperparameters
index = 1; % this part should be changed for multi dimensional cases
option.x_scale = hyper_p(2,index);                                          % scale x coordinate with the x direction bandwidth
option.y_scale = hyper_p(3,index);
location       = [location(:,1)/option.x_scale, location(:,2)/option.y_scale];      % rescale cartesian coordinates
location_noise = [location_noise(:,1)/option.x_scale,...
                  location_noise(:,2)/option.y_scale];

h = 1; % discritization factor
l=5.5; % $\ell: bandwidth$
%option.alpha = h^(-2) * 2; % $\ell = \frac{1}{h} \sqrt{\frac{\alpha}{2}}$
option.alpha = l^(-2) * 2;
option.kappa = (hyper_p(1,index)* 4 * pi * option.alpha)^-1;  % $\sigma_f^2 = \frac{1}{4 \pi \alpha \kappa}$
% because of normalization bandwith = 1 here
option.hyperparameters_possibilities = ...
    [option.kappa,          option.alpha,       1 ];
option.X_mesh = (150:5:450)/option.x_scale;
option.Y_mesh = (200:5:400)/option.y_scale;
option.T_mesh = (1:size(f,1));
[tmp_S1, tmp_S2] = meshgrid(option.X_mesh,option.Y_mesh);
option.grids = [reshape(tmp_S1,[],1) reshape(tmp_S2,[],1)];
nx = size(option.X_mesh,2) ;                                                % number of X grid
ny = size(option.Y_mesh,2) ;                                                % number of Y grid
nt = size(option.T_mesh,2) ;                                                % number of time steps
recOmg=cell(nt,1);
omegaSetSet=cell(nt,1);
truePosGrid=zeros(nt,2);
%fields=cell(nt,1);
%regression loop:
for t=1:nt
%     AgumentedData(t).y = f(t);
%     dist_grid_from_continous = ...
%         sqrt((option.grids(:,1) - location(t,1)).^2 + ...
%         (option.grids(:,2) - location(t,2)).^2);
%     [IC,IX] = sort(dist_grid_from_continous);
%     AgumentedData(t).possible_q.true_q = IX(1);
%     AgumentedData(t).possible_q.support_qt{1} = IX(1);
%     AgumentedData(t).possible_q.prior_qt = 1;
%     AgumentedData(t).possible_q.N_possible_qt = 1;
%     AgumentedData(t).possible_q.measuredposition = IX(1);
    
    AgumentedData(t).y = f(t);
    
    dist_grid_from_continous_true= ...
        sqrt((option.grids(:,1) - location(t,1)).^2 + ...
        (option.grids(:,2) - location(t,2)).^2);
    [IC_true,IX_true] = sort(dist_grid_from_continous_true);
    
    dist_grid_from_continous_noise = ...
        sqrt((option.grids(:,1) - location_noise(t,1)).^2 + ...
        (option.grids(:,2) - location_noise(t,2)).^2);
    [IC_noise,IX_noise] = sort(dist_grid_from_continous_noise);
    %[omegaSet,recOmg{t},truePosGrid(t,:)]=omegaMaker(option.grids,IX_true,IX_noise,nx,ny);
    [omegaSet,truePosGrid(t,:)]=omegaMaker2(option.grids,IX_true,IX_noise,noiseStd);
    omegaSetSet{t}=omegaSet;
    sizeOmg=size(omegaSet,1);
    AgumentedData(t).possible_q.true_q = IX_true(1);
%     for i=1:sizeOmg
%        AgumentedData(t).possible_q.support_qt{i}=omegaSet(i);
%        AgumentedData(t).possible_q.prior_qt{i} = 1/sizeOmg;
%     end
    AgumentedData(t).possible_q.support_qt{1} = omegaSet;
    AgumentedData(t).possible_q.prior_qt = 1/sizeOmg*ones(sizeOmg,1);
    AgumentedData(t).possible_q.N_possible_qt = sizeOmg; %??
    AgumentedData(t).possible_q.measuredposition = IX_noise(1);
end
ntheta= size(option.hyperparameters_possibilities,1);                       % number of possibilities for $theta$
n = size(option.grids,1);                                                   % number of spatial sites
N = option.agentnumbers;
x_width = option.X_mesh(end) - option.X_mesh(1) + option.finegridsize;
y_width = option.Y_mesh(end) - option.Y_mesh(1) + option.finegridsize;
phi = 0 ; 
% update noise variance parameters here
option.vehicle.ModelUncertanity = 5;  %previous: 4
option.vehicle.ObservationNoise = noiseStd;
option.s_e2 = 0.01;                      %Sigma(epsilon^2)0.01
%----- Construct precision matrix Qz---------------------------------------
muz_theta = zeros(n,ntheta);
Sigmaz_theta = zeros(n^2,ntheta);
for indtheta=1:ntheta 
    tmp1 = prec_mat_5by5(option.hyperparameters_possibilities(indtheta,1)...
        ,option.hyperparameters_possibilities(indtheta,2),nx,ny);
    Sigmaz_theta(:,indtheta) = reshape(tmp1^(-1),[],1);
end 

f_theta = log(option.hyperparameters_possibilities(:,end));
itmp = (1:2*N);
jtmp = kron((1:N)',[1;1]);
mux = zeros(2*N,1);
Sigmax = eye(2*N)*1000;  %1000??
mux_ = mux;
Sigmax_ = Sigmax;

for t=option.T_mesh 
    t %#ok<NOPTS>
    tic
    size(omegaSetSet{t},1)
    xtilda = reshape(option.grids(...
        AgumentedData(1,t).possible_q.measuredposition,:)',[],1);
    ztilda = AgumentedData(t).y;

    
    qt= AgumentedData(1,t).possible_q.support_qt{1,1}';
    for indj = 2:N
        qtN = AgumentedData(1,t).possible_q.support_qt{1,indj}';
        qt= [kron(ones(1,size(qtN,2)),qt);...
            kron(qtN,ones(1,size(qt,2)))];
    end
    Sigma_e = eye(2*size(qt,1))* option.vehicle.ObservationNoise;


    
    numberofpossibleqt = size(qt,2);
    Sigma_epsilon = eye(size(qt,1))* option.s_e2;
    f_qtandtheta = zeros(numberofpossibleqt,ntheta);
    muz_qandtheta =    zeros(n, 1);
    Sigmaz_qandtheta = zeros(n^2,1);
    for indq = 1:numberofpossibleqt
        q = qt(:,indq);
        H = sparse(1:N,q',ones(1,N),N,n);                                   % find the map $H_{qt}$ from $q{t}$ to spacial sites S.
        x = reshape(option.grids(q,:)',[],1);
        f_qt  = logmvnpdf2(x,mux_,Sigmax_,option);
        f_qtildaGqt  = logmvnpdf2(xtilda,x,Sigma_e,option);
        for indtheta = 1:ntheta
            muztheta = muz_theta(:,indtheta);
            Sigmaztheta      = reshape(Sigmaz_theta(:,indtheta),n,n);
            muztildatheta    = H * muztheta;                                % $mu_{tilde{zt}|theta,D{t-1},\q{t}}  =  H_{qt} mu_{z| theta,D{t-1}}$            
            Sigmaztildatheta = Sigma_epsilon + H * Sigmaztheta * H';
            f_ztilda = logmvnpdf(ztilda,muztildatheta,Sigmaztildatheta);
            % approximate the distribution of $\q{t},\theta |\D{0}{t}$           
            f_qtandtheta(indq,indtheta) = ...
                f_qtildaGqt  + f_theta(indtheta) + f_qt + f_ztilda;         % pi(q{t},theta|D{t})
            

        end
    end
    B=f_qtandtheta;
    tmp_c = log(sum(sum(exp(f_qtandtheta))));                               % Here we find normalization factor $tmp_c$
    %tmp_c
    if (abs(tmp_c)>1000)
        disp('PAUSE!!');
        dbstop;
    end
    f_qtandtheta = f_qtandtheta - tmp_c;                                    % After this line $f_qtandtheta$ is normalized, 
    pi_qtandtheta = exp(f_qtandtheta);                                      % $sum(pi_qtandtheta) = 1$.
    
    pi_theta = sum(pi_qtandtheta,1);                
    pi_theta = pi_theta/sum(pi_theta);                                      % Compensate computational error
    f_theta = log(pi_theta);
    pi_q = sum(pi_qtandtheta,2);
    
    % For the toures correction on the sampling positions measured  close
    % to the borders
    mux = zeros(2*N,1); %#ok<NASGU>
    xxx = zeros(2*N,numberofpossibleqt); %xxx: position of each qt
    for indj = 1:N
        xx = option.grids(qt(indj,:),:);
%         % uncomment for tourse
%         median_xx = median(xx);
%         tmp1 = find((xx(:,1) - median_xx(1))> x_width/2);
%         xx(tmp1,1) = xx(tmp1,1)- x_width;
%         tmp2 = find((xx(:,1) - median_xx(1))<-x_width/2);
%         xx(tmp2,1) = xx(tmp2,1)+ x_width;
%         tmp1 = find((xx(:,2) - median_xx(2))> y_width/2);
%         xx(tmp1,2) = xx(tmp1,2)- y_width;
%         tmp2 = find((xx(:,2) - median_xx(2))<-y_width/2);
%         xx(tmp2,2) = xx(tmp2,2)+ y_width;
        
        xxx((indj*2)-1:indj*2,:) = xx';
    end
    mux = (xxx * pi_q);
    Sigmax = reshape(...
        VectorSquare(xxx - mux * ones(1,numberofpossibleqt)) * pi_q,...
        2*N,2*N); 
    

    for indtheta = 1:ntheta
        pi_qtGtheta = (pi_qtandtheta(:,indtheta)/pi_theta(indtheta));
        muz_theta_temp = zeros(n,1);
        Sigmaz_theta_temp = zeros(n^2,1);
        for indq = 1:numberofpossibleqt
            q = qt(:,indq);
            H = sparse(1:N,q',ones(1,N),N,n);                               % find the map $H_{qt}$ from $q{t}$ to spacial sites S.
            muztheta = muz_theta(:,indtheta);
            Sigmaztheta      = reshape(Sigmaz_theta(:,indtheta),n,n);
            Sigmaztheta = 0.5 * (Sigmaztheta+Sigmaztheta');
            muztildatheta    = H * muztheta;
            tmp1 = Sigmaztheta * H';
            Sigmaztildatheta = Sigma_epsilon + H * tmp1;
            InvSigmaztildatheta = Sigmaztildatheta^(-1);
 
            muz_qandtheta    = ...
                muztheta + tmp1 * ...
                InvSigmaztildatheta * (ztilda - muztildatheta); %GP
            Sigmaz_qandtheta = ...
                reshape(Sigmaztheta - tmp1 * ...
                InvSigmaztildatheta * tmp1',[],1);  %GP
            
            muz_theta_temp = muz_theta_temp + ...
                muz_qandtheta * pi_qtGtheta(indq);

            Sigmaz_theta_temp = Sigmaz_theta_temp + ...
                (Sigmaz_qandtheta + VectorSquare(muz_qandtheta))*...
                pi_qtGtheta(indq) ;      

        end
        muz_theta(:,indtheta)    = muz_theta_temp; %(23)
        Sigmaz_theta(:,indtheta) = ...
            Sigmaz_theta_temp - VectorSquare(muz_theta_temp); %(24)
    end
    
    posterior(t).muz = muz_theta * pi_theta';
    posterior(t).varz= ...
        (Sigmaz_theta(1:n+1:end,:)+muz_theta.*muz_theta)* pi_theta' ...
        - posterior(t).muz.* posterior(t).muz;
    posterior(t).mux = mux;
    posterior(t).Sigmax = Sigmax;
    
    % predict next sampling position
    u = velocity(t);
    phi = phi + turnrate(t);
    stmp = reshape([cos(phi),sin(phi)]',[],1);
    F = sparse(itmp,jtmp,stmp,2*N,N);
    mux_    = mux + F * u;
    Sigma_w = eye(2*size(qt,1))* option.vehicle.ModelUncertanity;
    Sigmax_ = Sigmax + Sigma_w;  
    toc
    
end
% 
time=toc;
s=sprintf('run time: %f minutes',time/60);
disp(s);
% for i=1:463
%     DT_x(i) = posterior(i).mux(1);
%     DT_y(i) = posterior(i).mux(2);
% end
% for i=1:restricted
%     DT_x(i) = posterior(i).mux(1);
%     DT_y(i) = posterior(i).mux(2);
% end

for i=1:restricted/scaleRatio
    DT_x(i) = posterior(i).mux(1);
    DT_y(i) = posterior(i).mux(2);
end
figure(1);
plot(DT_x,DT_y,'b.--','MarkerSize',18,'LineWidth',2.5);
hold on;
plot(location_noise(:,1),location_noise(:,2),'g*','MarkerSize',12);
plot(location(:,1),location(:,2),'rd-','LineWidth',2.5);
% for i=1:nt
%    rectangle('Position',[recOmg{i}.point(1) (recOmg{i}.point(2)-recOmg{i}.height)...
%        recOmg{i}.width recOmg{i}.height]); 
% end

for i=1:nt
    plot(option.grids(omegaSetSet{i},1),option.grids(omegaSetSet{i},2),'g*');
end
hold off;
% s=input('output field animated: y or n?');
% if (s=='y')
%     writeObj=VideoWriter('test2.avi');
%     writeObj.FrameRate=5;
%     open(writeObj);
%     nFrames = nt;
%     mov(1:nFrames) = struct('cdata',[], 'colormap',[]);
%     for i=1:nt
%     C=reshape(posterior(i).muz,ny,nx);
%     surf(C);
%     mov(i)=getframe(gcf);
%     writeVideo(writeObj,mov(i));
%     end
%     close(writeObj);
% end
figure(2);
%normalize the filtered features
f_polished=downSampling(T(1:restricted),scaleRatio);
f_polished = f_polished - ones(size(f_polished,1),1)*mean(f_polished,1);            % remove mean average
cov_f = cov(f_polished);
[U,S,~] =  svd(cov_f);                                               % make feature orthogonal using SVD 
f_polished = f_polished*U*sqrt(S^-1);  

set(gcf,'DefaultAxesColorOrder',[0 0 1;1 0 0;0 1 0]);
hold all
D=reshape(posterior(end).muz,ny,nx);
plot3(truePosGrid(:,1),truePosGrid(:,2),f,'LineWidth',3.0,...
    'LineStyle','--');
plot3(truePosGrid(:,1),truePosGrid(:,2),f_polished,'LineWidth',3.0);
surf(option.X_mesh',option.Y_mesh',D,...
    'FaceColor','interp','EdgeColor','none','FaceLighting','phong');
axis tight
camlight right
material shiny

