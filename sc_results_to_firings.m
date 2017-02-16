function firings=sc_results_to_firings(hdf5_path)

X=load(hdf5_path,'-hdf5');
names=fieldnames(X.spiketimes);

clusters={};
for j=1:length(names)
times0=X.spiketimes.(names{j});
clusters{j}.times=times0;
end;

times0=zeros(1,0);
labels0=zeros(1,0);
for j=1:length(clusters)
times0=cat(2,times0,clusters{j}.times);
labels0=cat(2,labels0,j*ones(1,length(clusters{j}.times)));
end;

[~,ii]=sort(times0);
times0=times0(ii);
labels0=labels0(ii);

firings=zeros(3,length(times0));
firings(2,:)=times0;
firings(3,:)=labels0;
