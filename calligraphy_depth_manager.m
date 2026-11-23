function ui=calligraphy_depth_manager(~,cfg,glyph,selected,clipboard,onCopy,onApply,libraryFile)
% 模态编辑窗口：模板应用后复制数值，各笔仍可独立修改。
if nargin<8, libraryFile=fullfile(fileparts(mfilename('fullpath')),'data','depth_templates.json'); end
library=calligraphy_depth_templates('load',[],libraryFile);
f=uifigure('Name','提按模板 / 批量应用','Position',[130 130 980 640],'WindowStyle','modal');
layoutGrid=uigridlayout(f,[1 2]); layoutGrid.ColumnWidth={340,'1x'};
left=uigridlayout(layoutGrid,[4 1]); left.RowHeight={30,'1x',35,50};
uilabel(left,'Text','选择目标笔画（Ctrl / Shift 多选）','FontWeight','bold');
names=arrayfun(@(k)sprintf('第 %d 字“%s” · 第 %d 笔',glyph.strokeCharacterIndex(k), ...
    glyph.characters{glyph.strokeCharacterIndex(k)},glyph.localStrokeId(k)),1:numel(glyph.strokes),'UniformOutput',false);
targets=uilistbox(left,'Items',names,'ItemsData',1:numel(names),'Multiselect','on','Value',selected);
targets.ValueChangedFcn=@preview;
allButton=uibutton(left,'Text','选择全部笔画','ButtonPushedFcn',@selectAll);
uilabel(left,'Text','应用后各笔独立保存；修改一笔不会联动其他笔。','WordWrap','on');
right=uigridlayout(layoutGrid,[8 2]); right.RowHeight={32,32,32,32,'1x',35,42,45}; right.ColumnWidth={'1x','1x'};
copy=uibutton(right,'Text','复制主窗口当前笔画','ButtonPushedFcn',@copyCurrent);
source=uidropdown(right,'Items',{'剪贴板'},'ValueChangedFcn',@preview);
uilabel(right,'Text','模板名称'); name=uieditfield(right,'text');
save=uibutton(right,'Text','将当前笔画保存为模板','ButtonPushedFcn',@saveTemplate); save.Layout.Column=[1 2];
uilabel(right,'Text','应用深度倍率（仅缩放深度）'); scale=uieditfield(right,'numeric','Value',1,'Limits',[eps inf],'ValueChangedFcn',@preview);
ax=uiaxes(right); ax.Layout.Row=5; ax.Layout.Column=[1 2];
apply=uibutton(right,'Text','粘贴 / 应用到所选笔画','ButtonPushedFcn',@applySelected); apply.Layout.Row=6; apply.Layout.Column=[1 2];
message=uilabel(right,'Text','','WordWrap','on'); message.Layout.Row=7; message.Layout.Column=[1 2];
hint=uilabel(right,'Text','模板保存在项目 data/depth_templates.json；同名保存需确认覆盖。','WordWrap','on','Tooltip',libraryFile);
hint.Layout.Row=8; hint.Layout.Column=[1 2];
reloadSources('剪贴板'); preview;
ui=struct('figure',f,'targets',targets,'source',source,'name',name,'scale',scale, ...
    'copyButton',copy,'saveButton',save,'applyButton',apply,'allButton',allButton);

    function selectAll(~,~)
        targets.Value=1:numel(names);
    end
    function reloadSources(value)
        source.Items=[{'剪贴板'},strcat('模板：',{library.name})]; source.Value=value;
    end
    function points=sourcePoints
        if strcmp(source.Value,'剪贴板')
            assert(~isempty(clipboard),'Calligraphy:Clipboard','请先复制当前笔画，或选择已保存的模板。');
            points=clipboard;
        else
            index=find(strcmp(source.Items,source.Value))-1; points=library(index).points;
        end
        points(:,2)=points(:,2)*scale.Value;
    end
    function preview(varargin)
        cla(ax); xlabel(ax,'本笔累计弧长进度 (%)'); ylabel(ax,'下压深度 (mm)'); grid(ax,'on');
        try
            points=sourcePoints; s=linspace(0,1,401);
            plot(ax,s*100,calligraphy_depth(points,s,inf),'LineWidth',2); hold(ax,'on');
            plot(ax,points(:,1)*100,points(:,2),'o'); yline(ax,cfg.maxDepth,'r--','最大下压量');
            message.Text=sprintf('将应用到 %d 笔；深度倍率 %g。',numel(targets.Value),scale.Value);
        catch err, message.Text=err.message; end
    end
    function copyCurrent(~,~)
        clipboard=cfg.depthProfiles{selected}; onCopy(clipboard);
        source.Value='剪贴板'; preview;
    end
    function saveTemplate(~,~)
        try
            label=strtrim(name.Value); assert(~isempty(label),'Calligraphy:Templates','请填写模板名称，例如“横—轻起重收”。');
            % 重新读取，避免另一窗口刚保存的模板被旧库覆盖。
            updated=calligraphy_depth_templates('load',[],libraryFile); index=find(strcmp({updated.name},label),1);
            if ~isempty(index)
                answer=uiconfirm(f,['覆盖模板“' label '”？'],'同名模板','Options',{'覆盖','取消'},'DefaultOption',2,'CancelOption',2);
                if ~strcmp(answer,'覆盖'), return; end
            else, index=numel(updated)+1; end
            updated(index)=struct('name',label,'points',cfg.depthProfiles{selected});
            calligraphy_depth_templates('save',updated,libraryFile); library=updated;
            reloadSources(['模板：' label]); preview;
            message.Text='已保存当前笔画的原始六点曲线；应用倍率不写入模板。';
        catch err, uialert(f,err.message,'模板未保存'); end
    end
    function applySelected(~,~)
        try
            points=sourcePoints; calligraphy_depth(points,0,cfg.maxDepth);
            indices=targets.Value; assert(~isempty(indices),'Calligraphy:Targets','请至少选择一个目标笔画。');
            onApply(indices,points);
            for k=indices(:).', cfg.depthProfiles{k}=points; end
            message.Text=sprintf('已应用到 %d 笔；主窗口已更新，请重新生成轨迹。',numel(indices));
        catch err, uialert(f,err.message,'未应用曲线'); end
    end
end
