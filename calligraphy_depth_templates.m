function library=calligraphy_depth_templates(action,library,file)
% 项目内模板库；独立于单次文字配置，六点进度单位为 0..1。
if nargin<3, file=fullfile(fileparts(mfilename('fullpath')),'data','depth_templates.json'); end
if strcmp(action,'load')
    library=struct('name',{},'points',{});
    if ~isfile(file), return; end
    data=jsondecode(fileread(file));
    assert(data.version==1,'Calligraphy:Templates','不支持的模板库版本。');
    library=data.templates;
    if isempty(library), library=struct('name',{},'points',{}); end
else
    assert(strcmp(action,'save'),'Calligraphy:Templates','未知模板操作。');
end
for k=1:numel(library)
    assert(strlength(strtrim(string(library(k).name)))>0,'Calligraphy:Templates','模板名称不能为空。');
    calligraphy_depth(library(k).points,0,inf);
end
assert(numel(unique(string({library.name})))==numel(library),'Calligraphy:Templates','模板名称重复。');
if strcmp(action,'save')
    temporary=[tempname(fileparts(file)) '.json'];
    cleanup=onCleanup(@()removeTemporary(temporary));
    fid=fopen(temporary,'wt','n','UTF-8');
    assert(fid>=0,'Calligraphy:Templates','无法写入模板库。');
    try
        fprintf(fid,'%s',jsonencode(struct('version',1,'templates',library),'PrettyPrint',true));
        fclose(fid);
    catch err
        fclose(fid); rethrow(err);
    end
    [ok,message]=movefile(temporary,file,'f');
    assert(ok,'Calligraphy:Templates','模板保存失败：%s',message);
end
end
function removeTemporary(file)
if isfile(file), delete(file); end
end
