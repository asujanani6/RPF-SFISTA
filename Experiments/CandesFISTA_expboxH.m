clc;
clear;
close all;

N = [1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000];
M = [100,100,1000,1000,1000,1000,1000,1000,1e4,1e4,1e4,1e4];
m = [1e-1,1e-1,100,100,1,1,10,10,100,100,1000,1000];
seed =[777,777,777,777,777,777,777,777,777,777,777,777];
Problems=[1,2,3,4,5,6,7,8,9,10,11,12];
dimM = [500,500,500,500,500,500,1000,1000,1000,1000,1000,1000];
dimN = [1000,1000,1000,1000,1000,1000,2000,2000,2000,2000,2000,2000];
bscal=0;
lower=-5;
upper=5;
time_limit=7200;
%filename='CandesFISTA_vec_boxH_1-12.xlsx';
filename='CandesFISTA_vec_boxH_1_12_1013.xlsx';


for k=1:12
    avec=ones(dimN(k),1);
    if mod(k,2)==0
        avec(end-10:end)=-1;
    else
        avec(end)=-1;
    end

    Problem=Problems(k)
    [F, PAR]= test_fn_unconstr_hyper(N(k),M(k),m(k),seed(k),dimM(k),dimN(k),avec,bscal,lower,upper);

    PAR.initialnorm=norm(F.grad(PAR.x0))+1;
    PAR.L0=10;
    PAR.mu=0;
    PAR.chi=0.001;
    PAR.beta=1.25;
    PAR.last=1;
    tol=(norm(F.grad(PAR.x0))+1)*1e-13
    
    [y,L,FuncValue,NormComputeMin,totalIter,totalTime,Restarts]=RestartedFISTA(F,PAR,tol,time_limit);


    TimeFinal(k,1)=totalTime;
    Iterations(k,1)=totalIter;
    ResidualNorm(k,1)=NormComputeMin;
    FunctionValue(k,1)=FuncValue;
    NumberRestarts(k,1)=Restarts;

    writematrix(TimeFinal,filename,'Sheet',1,'Range','A1');
    writematrix(Iterations,filename,'Sheet',1,'Range','A15');
    writematrix(ResidualNorm,filename,'Sheet',1,'Range','A30');
    writematrix(FunctionValue,filename,'Sheet',1,'Range','A45');
    writematrix(NumberRestarts,filename,'Sheet',1,'Range','A60');

end



function [y,L,FuncValue,NormComputeMin,totalIter,totalTime,Restarts]=RestartedFISTA(F,PAR,tol,time_limit)

fistaFailure=1;
totalIter=0;
totalTime=0;
Restarts=-1;
NormComputeOld=Inf;

while fistaFailure==1
    Restarts=Restarts+1;
    [y,L,FuncValue,NormCompute,fistaFailure,iter,totalTime,FLAGTime]=FISTACandes(F,PAR,tol,time_limit,totalTime);

    NormComputeMin=min(NormComputeOld,NormCompute);
    NormComputeOld=NormCompute;

    totalIter=totalIter+iter
    if fistaFailure==0 || FLAGTime==1
        break
    end
    PAR.x0=y;
    PAR.mu=0.1*PAR.mu
    PAR.L0=L;
end

end




function [y,L,FuncValue,NormCompute,fistaFailure,iter,time,FLAGTime]=FISTACandes(F,PAR,tol,time_limit,totalTime)
iter=0;
FLAGTime=0;
x=PAR.x0;
y=PAR.x0;
A=0;
tau=1;
L=PAR.L0;
sumAL=0;
fistaFailure=0;
NormComputeOld=Inf;

tic
for j=1:1e6
    a=(tau+sqrt(tau^2+4*tau*A*L))/(2*L);
    xtilde=((A*y)+(a*x))/(A+a);
    storegradient=F.grad(xtilde);
    yold=y;
    FuncValueOld=F.fs(yold);

    y=F.prox(xtilde-(1/L)*storegradient);
    iter=iter+1

    if F.fs(xtilde)+PAR.prod_fn(y-xtilde,storegradient)+((1-PAR.chi)*L*PAR.norm_fn(y-xtilde)^2)/(4)+10^-6<F.fs(y)
        success=0;
        L=PAR.beta*L
    else
        success=1;
    end
    while success==0
        a=(tau+sqrt(tau^2+4*tau*A*L))/(2*L);
        xtilde=((A*y)+(a*x))/(A+a);
        storegradient=F.grad(xtilde);
        y=F.prox(xtilde-(1/L)*storegradient);
        iter=iter+1;
        if F.fs(xtilde)+PAR.prod_fn(y-xtilde,storegradient)+((1-PAR.chi)*L*PAR.norm_fn(y-xtilde)^2)/(4)+10^-6<F.fs(y)
            success=0;
            L=PAR.beta*L
        else
            success=1;
        end
    end


    s=L*(xtilde-y);
    u=F.grad(y)-storegradient+s;
    storegradient=[];
    A=A+a;
    oldtau=tau;
    tau=oldtau+(0.5*PAR.mu*a);
    x=(1/tau)*((0.5*PAR.mu*a*y)+(oldtau*x)-(a*s));

    NormCompute=PAR.norm_fn(u)

    NormMin=min(NormCompute,NormComputeOld);
    NormComputeOld=NormCompute;

    FuncValue=F.fs(y)

    if FuncValue-1e-6>FuncValueOld
        fistaFailure=1;
        y=yold;
        NormCompute=(NormMin/PAR.initialnorm);
        break
    end

    if totalTime+toc>=time_limit
        NormCompute=(NormMin/PAR.initialnorm);
        FLAGTime=1;
        break
    end

    if NormCompute<=tol
        NormCompute=(NormMin/PAR.initialnorm);
        break
    end




end
time=toc+totalTime;
end