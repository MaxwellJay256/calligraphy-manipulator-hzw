function app = calligraphy_app(cfg)
%CALLIGRAPHY_APP 六点可拖动的逐笔提按编辑器。运行：calligraphy_app
if nargin<1, cfg=calligraphy_config; end
[cfg,glyph]=calligraphy_prepare(cfg);
selected=1; characterSelected=1; result=[]; dragIndex=[]; busy=false; playing=false; velocityFigure=[];
endVelocityFigure=[];
accelerationFigure=[];
depthClipboard=[]; depthManager=[];
depthLine=[]; pointHandles=gobjects(6,1); pointLabels=gobjects(6,1);
controlHandle=[]; spaceHandles={}; strokeProgress={};
f=uifigure('Name','机械臂毛笔书写 | 六点提按规划','Position',[30 40 1450 900]);
f.CloseRequestFcn=@closeApp;
root=uigridlayout(f,[4 1]); root.RowHeight={42,38,'1x',44}; root.Padding=[12 10 12 10];
bar=uigridlayout(root,[1 11]); bar.Layout.Row=1;
bar.ColumnWidth={40,180,60,125,60,75,85,95,95,95,'1x'}; bar.Padding=[0 0 0 0];
uilabel(bar,'Text','文字'); charInput=uieditfield(bar,'text','Value',cfg.character,'ValueChangedFcn',@changeCharacter);
uilabel(bar,'Text','当前字'); charSelector=uidropdown(bar,'Items',characterNames,'ValueChangedFcn',@changeCurrentCharacter);
uilabel(bar,'Text','当前笔画'); selector=uidropdown(bar,'Items',strokeNames,'ValueChangedFcn',@changeStroke);
resetButton=uibutton(bar,'Text','恢复本笔','ButtonPushedFcn',@resetStroke);
copyButton=uibutton(bar,'Text','复制上一笔','ButtonPushedFcn',@copyStroke);
loadButton=uibutton(bar,'Text','读取配置','ButtonPushedFcn',@loadConfig);
saveButton=uibutton(bar,'Text','保存配置','ButtonPushedFcn',@saveConfig);
modeLabel=uilabel(bar,'Text','未标定示例 | 深度为位置下压量','FontColor',[.65 .25 .06]);
commands=uigridlayout(root,[1 8]); commands.Layout.Row=2;
commands.ColumnWidth={125,125,105,115,125,130,155,'1x'}; commands.Padding=[0 0 0 0];
generateButton=uibutton(commands,'Text','生成轨迹并检查','ButtonPushedFcn',@generate);
exportButton=uibutton(commands,'Text','导出 TXT / MAT','Enable','off','ButtonPushedFcn',@exportResult);
playButton=uibutton(commands,'Text','播放 / 停止','Enable','off','ButtonPushedFcn',@play);
simButton=uibutton(commands,'Text','准备 Simulink','Enable','off','ButtonPushedFcn',@prepareSim);
uibutton(commands,'Text','打开输出文件夹','ButtonPushedFcn',@openOutput);
sameCharacterButton=uibutton(commands,'Text','提按复制到同字','ButtonPushedFcn',@copySameCharacter);
templatesButton=uibutton(commands,'Text','提按模板 / 批量应用','ButtonPushedFcn',@openDepthManager);
uilabel(commands,'Text','准备 Simulink 只加载输入并打开模型；由你手动点击运行。');
body=uigridlayout(root,[1 2]); body.Layout.Row=3; body.ColumnWidth={'1x',370}; body.Padding=[0 0 0 0];
plots=uigridlayout(body,[2 2]); plots.Layout.Column=1;
axXY=uiaxes(plots); axXY.Layout.Row=1; axXY.Layout.Column=1;
axDepth=uiaxes(plots); axDepth.Layout.Row=1; axDepth.Layout.Column=2;
disableDefaultInteractivity(axDepth); axDepth.Toolbar.Visible='off';
ax3=uiaxes(plots); ax3.Layout.Row=2; ax3.Layout.Column=1;
axJoint=uiaxes(plots); axJoint.Layout.Row=2; axJoint.Layout.Column=2;
side=uigridlayout(body,[6 1]); side.Layout.Column=2;
side.RowHeight={30,170,36,30,'1x',65}; side.Padding=[0 0 0 0];
uilabel(side,'Text','六点编辑：拖动圆点，或修改下表','FontWeight','bold');
pointTable=uitable(side,'ColumnName',{'进度 (%)','下压深度 (mm)'}, ...
    'ColumnEditable',[true true],'RowName',{'1','2','3','4','5','6'},'CellEditCallback',@editPoint);
uilabel(side,'Text','首尾进度锁定；中间四点可横纵拖动。','WordWrap','on');
uilabel(side,'Text','物理参数与标定（向量用空格分隔）','FontWeight','bold');
keys={'Ts','squareSizeMm','charactersPerRow','characterGapMm','marginMm','writeSpeed','travelSpeed','verticalSpeed','cartAcceleration', ...
    'verticalAcceleration','liftHeight','maxDepth','paperOrigin','paperRpyDeg','brushRpyDeg', ...
    'toolOffsetMm','toolRpyDeg','qSeedDeg','jointSpeedDeg','jointAccelDeg','strokeSmoothingToleranceMm','calibrated'};
labels={'插补周期 s','单字字框边长 mm','每行字数（横排）','字框/行间距 mm','字框边距 mm','书写速度上限 mm/s','空移速度上限 mm/s', ...
    '提按速度上限 mm/s','笛卡尔加速度 mm/s²','提按加速度 mm/s²', ...
    '抬笔高度 mm','最大下压量 mm','整段文字中心 XYZ mm','纸面姿态 RPY deg', ...
    '笔尖相对纸面 RPY deg','末端到笔尖偏移 XYZ mm','末端到笔尖旋转 RPY deg', ...
    '逆解种子 q1..q6 deg','六轴速度上限 deg/s','六轴加速度上限 deg/s²','笔画平滑容差 mm','已标定 0/1'};
parameterTable=uitable(side,'Data',parameterData,'ColumnName',{'参数','值'}, ...
    'ColumnEditable',[false true],'ColumnWidth',{190,145},'RowName',{},'CellEditCallback',@editParameter);
uilabel(side,'Text',sprintf(['整笔连续运行，曲线接缝进行小范围平滑。\n' ...
    '安全起止点：[370, 0, 纸面高度+100] mm。\n字框尺寸约束为中心线，不是实际墨迹边界。']), ...
    'WordWrap','on','FontColor',[.45 .3 .1]);
status=uilabel(root,'Text','拖动深度点开始编辑；尚未生成机械臂轨迹。','WordWrap','on'); status.Layout.Row=4;
f.WindowButtonDownFcn=@beginFromWindow;
f.WindowButtonMotionFcn=@drag; f.WindowButtonUpFcn=@endDrag;
title(axJoint,'生成轨迹后显示六轴关节角'); xlabel(axJoint,'时间 (s)'); ylabel(axJoint,'关节角 (deg)');
refresh;
app=struct('figure',f,'xyAxes',axXY,'depthAxes',axDepth,'spaceAxes',ax3, ...
    'pointTable',pointTable,'parameterTable',parameterTable,'strokeSelector',selector,'characterSelector',charSelector, ...
    'characterInput',charInput,'generateButton',generateButton,'exportButton',exportButton, ...
    'copySameCharacterButton',sameCharacterButton, ...
    'depthTemplatesButton',templatesButton,'getDepthManager',@getDepthManager, ...
    'getConfig',@getConfig,'getResult',@getResult,'getGlyph',@getGlyph);

    function value=getConfig
        value=cfg;
    end
    function value=getResult
        value=result;
    end
    function value=getGlyph
        value=glyph;
    end
    function value=getDepthManager
        value=depthManager;
    end
    function openDepthManager(~,~)
        if busy, return; end
        try
            if ~isempty(depthManager) && isvalid(depthManager.figure), delete(depthManager.figure); end
            depthManager=calligraphy_depth_manager(f,cfg,glyph,selected,depthClipboard,@copyDepthClipboard,@applyDepthProfiles);
        catch err, showError(err); end
    end
    function copyDepthClipboard(points)
        depthClipboard=points;
    end
    function applyDepthProfiles(indices,points)
        calligraphy_depth(points,0,cfg.maxDepth);
        for k=indices(:).', cfg.depthProfiles{k}=points; end
        invalidate; refresh;
        setStatus(sprintf('已批量更新 %d 笔提按曲线，请重新生成轨迹。',numel(indices)));
    end

    function names=strokeNames
        count=sum(glyph.strokeCharacterIndex==characterSelected);
        names=arrayfun(@(i)sprintf('第 %d 笔',i),1:count,'UniformOutput',false);
    end
    function names=characterNames
        names=arrayfun(@(i)sprintf('第 %d 字：%s',i,glyph.characters{i}), ...
            1:numel(glyph.characters),'UniformOutput',false);
    end
    function data=parameterData
        data=cell(numel(keys),2);
        for k=1:numel(keys), data(k,:)={labels{k},strtrim(sprintf('%.10g ',cfg.(keys{k})))}; end
    end
    function setStatus(message)
        if isvalid(f), status.Text=message; drawnow limitrate; end
    end
    function invalidate
        result=[]; playing=false;
        if ~isempty(velocityFigure) && isgraphics(velocityFigure), delete(velocityFigure); end
        velocityFigure=[];
        if ~isempty(endVelocityFigure) && isgraphics(endVelocityFigure), delete(endVelocityFigure); end
        endVelocityFigure=[];
        if ~isempty(accelerationFigure) && isgraphics(accelerationFigure), delete(accelerationFigure); end
        accelerationFigure=[];
        exportButton.Enable='off'; playButton.Enable='off'; simButton.Enable='off';
        cla(axJoint); title(axJoint,'参数已变更，请重新生成轨迹');
    end
    function refresh
        charSelector.Items=characterNames; charSelector.Value=charSelector.Items{characterSelected};
        selector.Items=strokeNames; selector.Value=selector.Items{glyph.localStrokeId(selected)};
        profile=cfg.depthProfiles{selected}; pointTable.Data=[profile(:,1)*100,profile(:,2)];
        cla(axXY); hold(axXY,'on'); cla(ax3); hold(ax3,'on');
        half=cfg.squareSizeMm/2;
        for ch=1:numel(glyph.characters)
            center=glyph.characterCenters(ch,:);
            plot(axXY,center(1)+[-half half half -half -half], ...
                center(2)+[-half -half half half -half],'--','Color',[.6 .6 .6]);
            text(axXY,center(1)-half,center(2)+half,sprintf('%d：%s',ch,glyph.characters{ch}), ...
                'VerticalAlignment','bottom','Color',[.25 .25 .25]);
        end
        colors=lines(numel(glyph.strokes)); previous=[];
        for stroke=1:numel(glyph.strokes)
            st=glyph.strokes{stroke}; xy=zeros(0,2); s=zeros(0,1);
            for j=1:numel(st.segments)
                seg=st.segments(j); u=linspace(0,1,100).';
                xy=[xy;calligraphy_bezier(seg.B,u)]; %#ok<AGROW>
                s=[s;(st.cumulative(j)+interp1(seg.u,seg.ell,u,'pchip'))/st.length]; %#ok<AGROW>
            end
            d=calligraphy_depth(cfg.depthProfiles{stroke},s,cfg.maxDepth);
            width=1.3; if stroke==selected, width=2.8; end
            plot(axXY,xy(:,1),xy(:,2),'Color',colors(stroke,:),'LineWidth',width);
            text(axXY,xy(1,1),xy(1,2),sprintf(' %d.%d',glyph.strokeCharacterIndex(stroke),glyph.localStrokeId(stroke)), ...
                'Color',colors(stroke,:));
            spaceHandles{stroke}=plot3(ax3,xy(:,1),xy(:,2),-d,'Color',colors(stroke,:),'LineWidth',width);
            strokeProgress{stroke}=s;
            above=[xy(1,:) cfg.liftHeight]; last=[xy(end,:) cfg.liftHeight];
            if stroke==1
                [safeBase,safePaper]=calligraphy_safe_point(cfg); frames=calligraphy_frames(cfg);
                aboveBase=above*frames.paperR.'+frames.origin;
                via=([aboveBase(1:2),safeBase(3)]-frames.origin)*frames.paperR;
                path=[safePaper;via;above];
                plot3(ax3,path(:,1),path(:,2),path(:,3),'k--');
                scatter3(ax3,safePaper(1),safePaper(2),safePaper(3),55,'m','filled');
                text(ax3,safePaper(1),safePaper(2),safePaper(3),' 安全起点/终点');
            end
            if ~isempty(previous), plot3(ax3,[previous(1) above(1)],[previous(2) above(2)],[previous(3) above(3)],'k:'); end
            plot3(ax3,[above(1) above(1)],[above(2) above(2)],[cfg.liftHeight -d(1)],'k:');
            plot3(ax3,[last(1) last(1)],[last(2) last(2)],[-d(end) cfg.liftHeight],'k:'); previous=last;
        end
        lastBase=previous*frames.paperR.'+frames.origin;
        via=([lastBase(1:2),safeBase(3)]-frames.origin)*frames.paperR;
        path=[previous;via;safePaper];
        plot3(ax3,path(:,1),path(:,2),path(:,3),'k--');
        controlXY=strokePoints(glyph.strokes{selected},profile(:,1));
        controlHandle=scatter(axXY,controlXY(:,1),controlXY(:,2),36,[.85 .25 .08],'filled');
        axis(axXY,'equal'); xlim(axXY,glyph.layoutBounds(:,1).'+[-5 5]);
        ylim(axXY,glyph.layoutBounds(:,2).'+[-5 12]); grid(axXY,'on');
        xlabel(axXY,'纸面 X (mm)'); ylabel(axXY,'纸面 Y (mm)');
        title(axXY,sprintf('%s | 横排每行 %d 字 | 单字 %g mm',cfg.character,cfg.charactersPerRow,cfg.squareSizeMm));
        cla(axDepth); hold(axDepth,'on'); s=linspace(0,1,401);
        depthLine=plot(axDepth,s*100,calligraphy_depth(profile,s,cfg.maxDepth),'LineWidth',2,'Color',[.15 .4 .75]);
        depthLine.HitTest='off'; depthLine.PickableParts='none';
        for k=1:6
            h=plot(axDepth,profile(k,1)*100,profile(k,2),'o','MarkerSize',9, ...
                'MarkerFaceColor',[.95 .45 .12],'MarkerEdgeColor',[.5 .2 .05]);
            h.ButtonDownFcn=@(~,~)beginDrag(k);
            pointHandles(k)=h;
            pointLabels(k)=text(axDepth,profile(k,1)*100,profile(k,2),sprintf('  %d',k),'HitTest','off','PickableParts','none');
        end
        xlim(axDepth,[-3 103]); ylim(axDepth,[-.05*cfg.maxDepth 1.1*cfg.maxDepth]); grid(axDepth,'on');
        xlabel(axDepth,'本笔累计弧长进度 (%)'); ylabel(axDepth,'下压深度 (mm，正值向纸内)');
        title(axDepth,sprintf('第 %d 字“%s”第 %d 笔 · 拖动六点',characterSelected, ...
            glyph.characters{characterSelected},glyph.localStrokeId(selected)));
        xlabel(ax3,'纸面 X (mm)'); ylabel(ax3,'纸面 Y (mm)'); zlabel(ax3,'离纸高度 (mm)');
        title(ax3,'纸面坐标预览（虚线为空移/提笔）'); axis(ax3,'equal'); grid(ax3,'on'); view(ax3,40,30);
        if cfg.calibrated, modeLabel.Text='用户标记已标定 | 请核对控制器 TCP';
        else, modeLabel.Text='未标定示例 | 深度为位置下压量'; end
    end
    function beginDrag(k)
        if busy, return; end
        playing=false; dragIndex=k; status.Text=sprintf('正在拖动第 %d 个控制点',k);
    end
    function beginFromWindow(~,~)
        if busy || ~isempty(dragIndex), return; end
        cp=axDepth.CurrentPoint; p=cfg.depthProfiles{selected};
        distance=hypot(p(:,1)-cp(1,1)/100,(p(:,2)-cp(1,2))/cfg.maxDepth);
        [value,k]=min(distance);
        if value<.05, beginDrag(k); end
    end
    function drag(~,~)
        if isempty(dragIndex) || busy, return; end
        cp=axDepth.CurrentPoint; p=cfg.depthProfiles{selected}; k=dragIndex;
        p(k,2)=min(cfg.maxDepth,max(0,cp(1,2)));
        if k>1 && k<6, p(k,1)=min(p(k+1,1)-.01,max(p(k-1,1)+.01,cp(1,1)/100)); end
        cfg.depthProfiles{selected}=p;
        if ~isempty(result), invalidate; end
        depthLine.YData=calligraphy_depth(p,depthLine.XData/100,cfg.maxDepth);
        pointHandles(k).XData=p(k,1)*100; pointHandles(k).YData=p(k,2);
        pointLabels(k).Position=[p(k,1)*100,p(k,2),0];
        pointTable.Data=[p(:,1)*100,p(:,2)];
        xy=strokePoints(glyph.strokes{selected},p(:,1));
        controlHandle.XData=xy(:,1); controlHandle.YData=xy(:,2);
        spaceHandles{selected}.ZData=-calligraphy_depth(p,strokeProgress{selected},cfg.maxDepth);
        drawnow limitrate;
    end
    function endDrag(~,~)
        if ~isempty(dragIndex), dragIndex=[]; refresh; setStatus('深度曲线已更新；请重新生成轨迹。'); end
    end
    function editPoint(~,event)
        if busy, return; end
        old=cfg.depthProfiles{selected}; p=pointTable.Data; p(:,1)=p(:,1)/100;
        try
            if any(event.Indices(1)==[1 6]) && event.Indices(2)==1
                error('首尾点进度固定为 0%% 和 100%%。');
            end
            calligraphy_depth(p,0,cfg.maxDepth); cfg.depthProfiles{selected}=p;
            invalidate; refresh;
        catch err
            pointTable.Data=[old(:,1)*100 old(:,2)]; showError(err);
        end
    end
    function editParameter(~,event)
        if busy, return; end
        old=cfg;
        try
            key=keys{event.Indices(1)}; value=parameterTable.Data{event.Indices(1),2};
            if ischar(value) || isstring(value)
                value=str2double(regexp(strtrim(char(value)),'[\s,;]+','split'));
            end
            cfg.(key)=value; [cfg,glyph]=calligraphy_prepare(cfg);
            invalidate; refresh; parameterTable.Data=parameterData;
        catch err
            cfg=old; parameterTable.Data=parameterData; showError(err);
        end
    end
    function changeCharacter(~,~)
        if busy, return; end
        old=cfg;
        try
            cfg.character=charInput.Value; cfg.depthProfiles={};
            [cfg,glyph]=calligraphy_prepare(cfg); selected=1; characterSelected=1;
            selector.Items=strokeNames; selector.Value=selector.Items{1}; invalidate; refresh;
        catch err, cfg=old; charInput.Value=cfg.character; showError(err); end
    end
    function changeStroke(~,~)
        if busy, return; end
        indices=find(glyph.strokeCharacterIndex==characterSelected);
        selected=indices(find(strcmp(selector.Items,selector.Value))); refresh;
    end
    function changeCurrentCharacter(~,~)
        if busy, return; end
        characterSelected=find(strcmp(charSelector.Items,charSelector.Value));
        selected=find(glyph.strokeCharacterIndex==characterSelected,1); refresh;
    end
    function copySameCharacter(~,~)
        if busy, return; end
        source=find(glyph.strokeCharacterIndex==characterSelected);
        matches=find(strcmp(glyph.characters,glyph.characters{characterSelected}));
        for ch=matches
            target=find(glyph.strokeCharacterIndex==ch);
            cfg.depthProfiles(target)=cfg.depthProfiles(source);
        end
        invalidate; refresh; setStatus('当前字的逐笔提按已复制到文字中相同汉字。');
    end
    function resetStroke(~,~)
        if busy, return; end
        cfg.depthProfiles{selected}=[cfg.depthProgress(:),cfg.depthDefault(:)]; invalidate; refresh;
    end
    function copyStroke(~,~)
        if busy || selected==1, return; end
        cfg.depthProfiles{selected}=cfg.depthProfiles{selected-1}; invalidate; refresh;
    end
    function loadConfig(~,~)
        if busy, return; end
        [file,path]=uigetfile('*.json','读取书写配置'); if isequal(file,0), return; end
        try
            incoming=calligraphy_load_config(fullfile(path,file)); [incoming,newGlyph]=calligraphy_prepare(incoming);
            cfg=incoming; glyph=newGlyph; selected=1; characterSelected=1; selector.Items=strokeNames; selector.Value=selector.Items{1};
            charInput.Value=cfg.character; parameterTable.Data=parameterData; invalidate; refresh;
        catch err, showError(err); end
    end
    function saveConfig(~,~)
        [file,path]=uiputfile('*.json','保存书写配置','calligraphy_config.json'); if isequal(file,0), return; end
        try, calligraphy_save_config(cfg,fullfile(path,file)); setStatus('六点曲线和标定参数已保存。'); catch err, showError(err); end
    end
    function generate(~,~)
        if busy, return; end
        invalidate; busy=true; setControls('off');
        try
            result=plan_calligraphy(cfg,@setStatus);
            exportButton.Enable='on'; playButton.Enable='on'; simButton.Enable='on';
            plot(axJoint,result.trajectory.t,rad2deg(result.trajectory.q),'LineWidth',1);
            xlabel(axJoint,'时间 (s)'); ylabel(axJoint,'关节角 (deg)'); grid(axJoint,'on');
            title(axJoint,sprintf('检查通过 | %d 点 | %.2f s',numel(result.trajectory.t),result.trajectory.t(end)));
            legend(axJoint,{'J1','J2','J3','J4','J5','J6'},'Location','best');
            velocityFigure=plot_calligraphy_joint_velocity(result);
            endVelocityFigure=plot_calligraphy_end_velocity(result);
            accelerationFigure=plot_calligraphy_joint_acceleration(result);
        catch err, result=[]; showError(err); end
        finishBusy;
    end
    function finishBusy
        busy=false; if isvalid(f), setControls('on'); end
    end
    function setControls(state)
        controls={charInput,charSelector,selector,resetButton,copyButton,sameCharacterButton,templatesButton,loadButton,saveButton,generateButton,pointTable,parameterTable};
        for k=1:numel(controls), controls{k}.Enable=state; end
    end
    function exportResult(~,~)
        if isempty(result) || busy, return; end
        try, folder=export_calligraphy(result); setStatus(['已导出：' folder]); catch err, showError(err); end
    end
    function play(~,~)
        if playing, playing=false; return; end
        if isempty(result) || busy, return; end
        playing=true; tr=result.trajectory; frames=calligraphy_frames(cfg);
        marker=plot3(ax3,nan,nan,nan,'ro','MarkerFaceColor','r','MarkerSize',7);
        cleanup=onCleanup(@()deleteMarker(marker));
        ix=unique(round(linspace(1,numel(tr.t),min(350,numel(tr.t)))));
        for i=ix
            if ~isvalid(f) || ~playing || ~isgraphics(marker), break; end
            T=HL0905Fkine(tr.q(i,:))*frames.modelToTip;
            p=(T(1:3,4).'-frames.origin)*frames.paperR;
            marker.XData=p(1); marker.YData=p(2); marker.ZData=p(3);
            if tr.strokeId(i)==0
                title(ax3,sprintf('正解笔尖回放 t=%.2f s | 安全点进出运动',tr.t(i)));
            else
                title(ax3,sprintf('正解笔尖回放 t=%.2f s | 第 %d 字“%s”第 %d 笔 | %s', ...
                    tr.t(i),tr.characterIndex(i),glyph.characters{tr.characterIndex(i)},tr.localStrokeId(i),tr.phase(i)));
            end
            drawnow; pause(.015);
        end
        playing=false;
    end
    function prepareSim(~,~)
        if isempty(result), return; end
        try, prepare_calligraphy_simulink(result); setStatus('已准备工作区和模型，尚未运行；请在 Simulink 中手动点击运行。'); catch err, showError(err); end
    end
    function openOutput(~,~)
        folder=fullfile(fileparts(mfilename('fullpath')),'results');
        if isfolder(folder), winopen(folder); else, setStatus('尚未导出文件。'); end
    end
    function showError(err)
        setStatus(['未完成：' err.message]); uialert(f,err.message,'请检查输入');
    end
    function closeApp(~,~)
        if busy, setStatus('正在检查轨迹，完成后可关闭窗口。'); return; end
        playing=false;
        if ~isempty(depthManager) && isvalid(depthManager.figure), delete(depthManager.figure); end
        if ~isempty(velocityFigure) && isgraphics(velocityFigure), delete(velocityFigure); end
        if ~isempty(endVelocityFigure) && isgraphics(endVelocityFigure), delete(endVelocityFigure); end
        if ~isempty(accelerationFigure) && isgraphics(accelerationFigure), delete(accelerationFigure); end
        delete(f);
    end
end

function xy=strokePoints(st,s)
xy=zeros(numel(s),2);
for k=1:numel(s)
    ell=s(k)*st.length; j=find(st.cumulative(2:end)>=ell-1e-10,1);
    if isempty(j), j=numel(st.segments); end
    seg=st.segments(j); local=min(seg.length,max(0,ell-st.cumulative(j)));
    u=interp1(seg.ell,seg.u,local,'pchip'); xy(k,:)=calligraphy_bezier(seg.B,u);
end
end
function deleteMarker(marker)
if isgraphics(marker), delete(marker); end
end
