#!/usr/bin/env nodejs

function get_spec() {
	var processors=[];
	processors.push({
	    name: "ml_spyking_circus",
	    version: "0.1",
	    exe_command: __filename+' $(arguments)',
	    description: "",
	    inputs: [
	        {name: "timeseries"}
	    ],
	    outputs: [
	        {name: "firings_out"}
	    ],
	    parameters: [
	        {name: "samplerate",optional: false},{name:"spike_thresh",optional:true}
	    ]
	});
	return {processors:processors};
}

var fs=require('fs');
var os=require('os');
var CLP=new CLParams(process.argv);

var arg1=CLP.unnamedParameters[0]||'';
if (arg1=='spec') {
	var spec=get_spec();
	console.log (JSON.stringify(spec));
	return;
}


var timeseries=CLP.namedParameters['timeseries']||'';
var firings_out=CLP.namedParameters['firings_out']||'';
var tempdir=CLP.namedParameters['_tempdir']||'';
var num_threads=CLP.namedParameters['_request_num_threads']||os.cpus().length;
var ppp={};
ppp.samplerate=CLP.namedParameters['samplerate']||0;
ppp.geom_radius=100;
ppp.spike_thresh=CLP.namedParameters['spike_thresh']||6;

if (!timeseries) {
	console.log('timeseries is empty')
	process.exit(-1);
}
if (!firings_out) {
	console.log('firings_out is empty')
	process.exit(-1);
}
if (!tempdir) {
	console.log('timeseries is empty')
	process.exit(-1);
}
if (!ppp.samplerate) {
	console.log('missing parameter: samplerate')
	process.exit(-1);	
}

var dat_fname=tempdir+'/mlsc.mda';

step1();

function step1() {
	console.log('Copying raw data '+timeseries+' to '+dat_fname+'...');
	copy_file(timeseries,dat_fname,function() {
		console.log('Reading .mda header...\n');
		read_mda_header(timeseries,function(HH) {
			step2(HH);
		});
	});
}

function step2(HH) {
	var M=HH.dims[0]; //number of channels
	var N=HH.dims[1]; //number of timepoints

	console.log('Making .prb file...\n');
	var prb=read_text_file(__dirname+'/template.prb');
	prb=fill_in_prb(prb);
	write_text_file(tempdir+'/mlsc.prb',prb);

	console.log('Making .params file...\n');
	var params=read_text_file(__dirname+'/template.params');
	params=fill_in_parameters(params);
	write_text_file(tempdir+'/mlsc.params',params);

	step3();

	function fill_in_parameters(params) {
		params=strrepl(params,'$header_size$',HH.header_size);
		params=strrepl(params,'$prb_file$',tempdir+'/mlsc.prb');
		params=strrepl(params,'$dtype$',HH.data_type_string);
		params=strrepl(params,'$samplerate$',ppp.samplerate);
		params=strrepl(params,'$template_width_ms$',3); //Width of the templates [in ms]
		params=strrepl(params,'$spike_thresh$',ppp.spike_thresh); // Threshold for spike detection (e.g., 6)
		params=strrepl(params,'$peaks$','both'); //positive,negative, or both
		return params;
	}

	function fill_in_prb(prb) {
		prb=strrepl(prb,'$num_channels$',M);
		prb=strrepl(prb,'$radius$',ppp.geom_radius);
		var geometry='{\n';
		for (var m=0; m<M; m++) {
			geometry+=m+': ['+0+','+m+'],\n';
		}
		geometry+='}';
		prb=strrepl(prb,'$geometry$',geometry);
		return prb;
	}
}

function step3() {
	console.log('Running spyking-circus...\n');
	make_system_call('spyking-circus',[dat_fname,'-c',num_threads],{show_stderr:true,show_stdout:true},function() {
		step4();
	});
}

var firings_fname=tempdir+'/firings.mda';
function step4() {
	console.log('Converting output to firings.mda...\n');
	var cmd='';
	cmd+="addpath('"+__dirname+"'); firings=sc_results_to_firings('"+tempdir+"/mlsc/mlsc.result.hdf5'); writemda64(firings,'"+firings_fname+"');";
	console.log('Running in octave: '+cmd);
	run_in_octave(cmd,function() {
		step5();
	});
}

function step5() {
	copy_file(firings_fname,firings_out,function() {
		//done
	});
}

function CLParams(argv) {
	this.unnamedParameters=[];
	this.namedParameters={};

	var args=argv.slice(2);
	for (var i=0; i<args.length; i++) {
		var arg0=args[i];
		if (arg0.indexOf('--')===0) {
			arg0=arg0.slice(2);
			var ind=arg0.indexOf('=');
			if (ind>=0) {
				this.namedParameters[arg0.slice(0,ind)]=arg0.slice(ind+1);
			}
			else {
				this.namedParameters[arg0]=args[i+1]||'';
				i++;
			}
		}
		else if (arg0.indexOf('-')===0) {
			arg0=arg0.slice(1);
			this.namedParameters[arg0]='';
		}
		else {
			this.unnamedParameters.push(arg0);
		}
	}
};

function read_mda_header(path,callback) {
	var exe='mdaconvert';
	var args=[path,'--readheader'];
	make_system_call(exe,args,{num_tries:1},function(aa) {
		callback(JSON.parse(aa.stdout));
	});
}

function copy_file(src,dst,callback) {
	var exe='cp';
	var args=[src,dst];
	make_system_call(exe,args,{num_tries:1},function(aa) {
		callback();
	});	
}

function make_system_call(cmd,args,opts,callback) {
	var num_tries=opts.num_tries||1;
	var child_process=require('child_process');
	console.log('Calling: '+cmd+' '+args.join(' '));
	var pp=child_process.spawn(cmd,args);
	pp.stdout.setEncoding('utf8');
	pp.stderr.setEncoding('utf8');
	var done=false;
	pp.on('close', function(code) {
		return_it(code);
	});
	//pp.on('exit', function(code) {
	//	return_it();
	//});
	pp.on('error',function(err) {
		console.log ('Process error: '+cmd+' '+args.join(' '));
		console.log (err);
	});
	var all_stdout='';
	var all_stderr='';
	pp.stdout.on('data',function(data) {
		if (opts.show_stdout) {
			console.log(data);
		}
		all_stdout+=data;
	});
	pp.stderr.on('data',function(data) {
		if (opts.show_stderr) {
			console.log(data);
		}
		all_stderr+=data;
	});
	function return_it(code) {
		if (done) return;
		if (code!=0) {
			if (num_tries>1) {
				console.error ('Re-trying system call: '+cmd+' '+args.join(' '));
				opts.num_tries=opts.num_tries-1; //todo, I really should not manipulate the opts here. very bad idea
				make_system_call(cmd,args,opts,callback);
				return;
			}
			else {
				console.log('Error in system call: '+cmd+' '+args.join(' '));
				process.exit(-1);
			}
		}
  		done=true;
		if (callback) {
			callback({stdout:all_stdout,stderr:all_stderr,return_code:code});
		}
	}
}

function strrepl(str,str1,str2) {
	return str.split(str1).join(str2);
}

function read_text_file(path) {
	return fs.readFileSync(path,'utf8');
}

function write_text_file(path,txt) {
	return fs.writeFileSync(path,txt,'utf8');
}

function run_in_octave(command,callback) {
	var cmd='octave';
	var args=['--no-gui','--eval'];
	args.push(command);
	make_system_call(cmd,args,{show_stdout:true,show_stderr:true},callback);
}
