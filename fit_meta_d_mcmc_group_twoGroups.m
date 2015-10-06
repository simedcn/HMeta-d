function fit = fit_meta_d_mcmc_group_twoGroups(nR_S1, nR_S2, grpind, mcmc_params, s, fncdf, fninv)
% fit = fit_meta_d_mcmc_group_twoGroups(nR_S1, nR_S2, grpind, mcmc_params, s, fncdf, fninv)
%
% See fit_meta_d_mcmc_group for further details
%
% grpind is a 1xNsubjects vector of 0's and 1's indicating membership of group A (=0)
% or group B (=1)
%
% Steve Fleming 2015

if ~exist('s','var') || isempty(s)
    s = 1;
end

if ~exist('fncdf','var') || isempty(fncdf)
    fncdf = @normcdf;
end

if ~exist('fninv','var') || isempty(fninv)
    fninv = @norminv;
end

Nsubj = length(nR_S1);

if ~exist('grpind','var') || isempty(grpind)
    grpind = zeros(Nsubj,1);
end

nRatings = length(nR_S1{1})/2;
c1_index = nRatings;
padFactor = 1/(2*nRatings);

for n = 1:Nsubj
    
    if length(nR_S1{n}) ~= nRatings*2 || length(nR_S2{n}) ~= nRatings*2
        error('Subjects do not have equal numbers of response categories');
    end
    % Get type 1 SDT parameter values
    counts(n,:) = [nR_S1{n} nR_S2{n}];
    nTot(n) = sum(counts(n,:));
    pad_nR_S1 = nR_S1{n} + padFactor;
    pad_nR_S2 = nR_S2{n} + padFactor;
    
    j=1;
    for c = 2:nRatings*2
        ratingHR(j) = sum(pad_nR_S2(c:(nRatings*2)))/sum(pad_nR_S2);
        ratingFAR(j) = sum(pad_nR_S1(c:(nRatings*2)))/sum(pad_nR_S1);
        j=j+1;
    end
    
    % Get type 1 estimate (from pair of middle HR/FAR ratings)
    d1(n) = norminv(ratingHR(c1_index))-norminv(ratingFAR(c1_index));
    c1(n) = -0.5 * (norminv(ratingHR(c1_index)) + norminv(ratingFAR(c1_index)));
end

%% Sampling
if ~exist('mcmc_params','var') || isempty(mcmc_params)
    % MCMC Parameters
    mcmc_params.response_conditional = 0;
    mcmc_params.nchains = 3; % How Many Chains?
    mcmc_params.nburnin = 1000; % How Many Burn-in Samples?
    mcmc_params.nsamples = 10000;  %How Many Recorded Samples?
    mcmc_params.nthin = 1; % How Often is a Sample Recorded?
    mcmc_params.doparallel = 0; % Parallel Option
    mcmc_params.dic = 1;
    % Initialize Unobserved Variables
    for i=1:mcmc_params.nchains
        mcmc_params.init0(i) = struct;
    end
end
% Assign variables to the observed nodes
datastruct = struct('nsubj',Nsubj,'counts', counts, 'd1', d1, 'c', c1, 'nratings', nRatings, 'nTot', nTot, 'Tol', 1e-05, 'grpind', grpind);

model_file = 'Bayes_metad_group_twoGroups.txt';
monitorparams = {'mu_Mratio','lambda_Mratio','mu_MratioG','lambda_MratioG','diff','MratioBaseline','Mratio','cS1','cS2'};


% Use JAGS to Sample
tic
fprintf( 'Running JAGS ...\n' );
[samples, stats] = matjags( ...
    datastruct, ...
    fullfile(pwd, model_file), ...
    mcmc_params.init0, ...
    'doparallel' , mcmc_params.doparallel, ...
    'nchains', mcmc_params.nchains,...
    'nburnin', mcmc_params.nburnin,...
    'nsamples', mcmc_params.nsamples, ...
    'thin', mcmc_params.nthin, ...
    'dic', mcmc_params.dic,...
    'monitorparams', monitorparams, ...
    'savejagsoutput' , 0 , ...
    'verbosity' , 1 , ...
    'cleanup' , 1 , ...
    'workingdir' , 'tmpjags' );
toc

% Package group-level output

fit.mu_Mratio = stats.mean.mu_Mratio;
fit.lambda_Mratio = stats.mean.lambda_Mratio;
fit.mu_MratioG = stats.mean.mu_MratioG;
fit.lambda_MratioG = stats.mean.lambda_MratioG;
fit.diff = stats.mean.diff;
fit.MratioBaseline = stats.mean.MratioBaseline;
fit.Mratio = stats.mean.Mratio;
fit.meta_d   = fit.Mratio.*d1;
fit.meta_da = sqrt(2/(1+s^2)) * s * fit.meta_d;

fit.da        = sqrt(2/(1+s^2)) .* s .* d1;
fit.s         = s;
fit.meta_ca   = ( sqrt(2).*s ./ sqrt(1+s.^2) ) .* c1;
fit.t2ca_rS1  = ( sqrt(2).*s ./ sqrt(1+s.^2) ) .* stats.mean.cS1;
fit.t2ca_rS2  = ( sqrt(2).*s ./ sqrt(1+s.^2) ) .* stats.mean.cS2;

fit.mcmc.dic = stats.dic;
fit.mcmc.Rhat = stats.Rhat;
fit.mcmc.samples = samples;
fit.mcmc.params = mcmc_params;

for n = 1:Nsubj
    
    
    %% Data is fit, now package output
    I_nR_rS2 = nR_S1{n}(nRatings+1:end);
    I_nR_rS1 = nR_S2{n}(nRatings:-1:1);
    
    C_nR_rS2 = nR_S2{n}(nRatings+1:end);
    C_nR_rS1 = nR_S1{n}(nRatings:-1:1);
    
    for i = 2:nRatings
        obs_FAR2_rS2(i-1) = sum( I_nR_rS2(i:end) ) / sum(I_nR_rS2);
        obs_HR2_rS2(i-1)  = sum( C_nR_rS2(i:end) ) / sum(C_nR_rS2);
        
        obs_FAR2_rS1(i-1) = sum( I_nR_rS1(i:end) ) / sum(I_nR_rS1);
        obs_HR2_rS1(i-1)  = sum( C_nR_rS1(i:end) ) / sum(C_nR_rS1);
    end
    
    
    %% find estimated t2FAR and t2HR
    meta_d = fit.meta_d(n);
    S1mu = -meta_d/2; S1sd = 1;
    S2mu =  meta_d/2; S2sd = S1sd/s;
    
    C_area_rS2 = 1-fncdf(c1(n),S2mu,S2sd);
    I_area_rS2 = 1-fncdf(c1(n),S1mu,S1sd);
    
    C_area_rS1 = fncdf(c1(n),S1mu,S1sd);
    I_area_rS1 = fncdf(c1(n),S2mu,S2sd);
    
    t2c1 = [fit.t2ca_rS1(n,:) fit.t2ca_rS2(n,:)];
    
    for i=1:nRatings-1
        
        t2c1_lower = t2c1(nRatings-i);
        t2c1_upper = t2c1(nRatings-1+i);
        
        I_FAR_area_rS2 = 1-fncdf(t2c1_upper,S1mu,S1sd);
        C_HR_area_rS2  = 1-fncdf(t2c1_upper,S2mu,S2sd);
        
        I_FAR_area_rS1 = fncdf(t2c1_lower,S2mu,S2sd);
        C_HR_area_rS1  = fncdf(t2c1_lower,S1mu,S1sd);
        
        
        est_FAR2_rS2(i) = I_FAR_area_rS2 / I_area_rS2;
        est_HR2_rS2(i)  = C_HR_area_rS2 / C_area_rS2;
        
        est_FAR2_rS1(i) = I_FAR_area_rS1 / I_area_rS1;
        est_HR2_rS1(i)  = C_HR_area_rS1 / C_area_rS1;
        
    end
    
    fit.est_HR2_rS1(n,:)  = est_HR2_rS1;
    fit.obs_HR2_rS1(n,:)  = obs_HR2_rS1;
    
    fit.est_FAR2_rS1(n,:) = est_FAR2_rS1;
    fit.obs_FAR2_rS1(n,:) = obs_FAR2_rS1;
    
    fit.est_HR2_rS2(n,:)  = est_HR2_rS2;
    fit.obs_HR2_rS2(n,:)  = obs_HR2_rS2;
    
    fit.est_FAR2_rS2(n,:) = est_FAR2_rS2;
    fit.obs_FAR2_rS2(n,:) = obs_FAR2_rS2;
end
