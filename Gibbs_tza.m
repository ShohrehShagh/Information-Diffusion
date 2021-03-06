function [just_t_hat]=Gibbs_tza(N,pi,L0,a_mat,b_mat,mu1,mu2,sigma1,sigma2,Number_of_samples,data_num,Number_of_batches,Burn_in,N_thin,r,pdf_val)
load(sprintf('input_datas/Data_%d_%d',data_num,r));
all_data=Real.d;
T=Real.T;
BL=floor(T/Number_of_batches);
%% Gibbs Initial Values
S_alphas_init=zeros(N,N);
S_alphas_init(pi==1)=gamrnd(a_mat(pi==1),b_mat(pi==1));
S_alphas_init=tril(S_alphas_init,-1)'+S_alphas_init;
S_parents_init=zeros(1,N);
for i=L0+1:N
    p_vector=find(pi(i,:)>0);
    P=ones(1,length(p_vector));
    S_parents_init(i)=p_vector(find(rand <= cumsum(P)/sum(P), 1));
end
S_changepoints_init=zeros(1,N);
for i=L0+1:N
    p=S_parents_init(i);
    p_alpha=1-exp(-S_alphas_init(i,p));
    S_changepoints_init(i)=S_changepoints_init(p)+geornd(p_alpha)+1;
end
particle_size=(Number_of_samples-Burn_in)/N_thin;
Samples.parents=NaN(Number_of_samples-Burn_in,N);
Samples.changepoints=NaN(Number_of_samples-Burn_in,N);
Samples.alphas=cell(Number_of_samples-Burn_in,1);
Samples_To_Save.parents=NaN(particle_size,N);
Samples_To_Save.changepoints=NaN(particle_size,N);
Samples_To_Save.alphas=cell(particle_size,1);
%% initialization
S_parents=S_parents_init;
S_alphas=S_alphas_init;
S_changepoints=S_changepoints_init;
batch=1;
t_start_batch=BL*(batch-1)+1;
t_end_batch=min(BL*batch,T);
data=all_data(:,t_start_batch:t_end_batch);
term=term_calculator(data,mu1,mu2,sigma1,sigma2);
for m=1:Number_of_samples
    for n1=L0+1:N
        % parents
        S_parents(n1)=Sample_parent(S_changepoints,S_alphas,S_parents,pi,n1,t_start_batch,BL);
        % infection times
        S_changepoints(n1)=Sample_changepoint(S_changepoints,S_parents,n1,S_alphas,BL,term(n1,:),pi,m);
        % \alphas
        S_alphas=Sample_alpha(S_parents,n1,S_changepoints,S_alphas,a_mat(n1,:),b_mat(n1,:),pi,N,size(term,2),pdf_val);
    end
    if (m>Burn_in)
        Samples.parents(m-Burn_in,:)=S_parents;
        Samples.changepoints(m-Burn_in,:)=S_changepoints;
        Samples.alphas{m-Burn_in}=S_alphas;
        if(mod(m,N_thin)==0)
            Samples_To_Save.parents((m-Burn_in)/N_thin,:)=S_parents;
            Samples_To_Save.changepoints((m-Burn_in)/N_thin,:)=S_changepoints;
            Samples_To_Save.alphas{(m-Burn_in)/N_thin}=S_alphas;
        end
    end
end

if(Number_of_batches==1)
    save(sprintf('Samples/total/Samples_tza_%d_%d',data_num,r),'Samples_To_Save','-v7.3')
else
    save(sprintf('Samples/Samples_tza_%d_%d',data_num,r),'Samples_To_Save','-v7.3')
end
Samples.changepoints(isnan(Samples.changepoints))=Inf;
Samples.parents(isnan(Samples.parents))=Inf;
%
z_and_tcs=[Samples.parents Samples.changepoints];
z_and_tcs(isnan(z_and_tcs))=inf;%%
[a_tz,~,c_tz] = unique(z_and_tcs,'rows');
ac_tz=[a_tz accumarray(c_tz,1)];
[~,sort_ind]=sort(accumarray(c_tz,1),'descend');

marginal_tcs=mode(Samples.changepoints);
z_hat=a_tz(sort_ind(1),1:N);
t_hat=a_tz(sort_ind(1),N+1:2*N);
indices=find(c_tz==sort_ind(1));
alpha_hat=zeros(N,N);
for j=1:length(indices)
    alpha_hat=alpha_hat+Samples.alphas{indices(j)};
end
alpha_hat=alpha_hat/length(indices);
hats.t=t_hat;
hats.z=z_hat;
hats.a=alpha_hat;
just_t_hat=Just_t(N,1,term,L0,BL);
hats.just_t=just_t_hat';
hats.just_t(isnan(just_t_hat))=Inf;
hats.marg_t=marginal_tcs;
hats
if(Number_of_batches==1)
    save(sprintf('Final_Results/total/tza_%d_%d',data_num,r),'hats','-v7.3')
else
    save(sprintf('Final_Results/tza_%d_%d',data_num,r),'hats','-v7.3')
end