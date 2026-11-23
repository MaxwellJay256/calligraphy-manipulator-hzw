function test_depth_reuse
% 只检查复用编辑和模板持久化，不生成轨迹或启动仿真。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
app=calligraphy_app(calligraphy_config('人人'));
cleanup=onCleanup(@()delete(app.figure));
app.depthTemplatesButton.ButtonPushedFcn([],[]); ui=app.getDepthManager();
dialogCleanup=onCleanup(@()closeFigure(ui.figure));
ui.copyButton.ButtonPushedFcn([],[]); ui.targets.Value=[2 3]; ui.scale.Value=.8;
ui.applyButton.ButtonPushedFcn([],[]);
cfg=app.getConfig(); original=cfg.depthProfiles{1}; expected=original; expected(:,2)=expected(:,2)*.8;
assert(isequal(cfg.depthProfiles{2},expected) && isequal(cfg.depthProfiles{3},expected));
assert(isequal(cfg.depthProfiles{4},original)); clear dialogCleanup
% 剪贴板跨窗口保留；重复应用倍率不累乘。
app.depthTemplatesButton.ButtonPushedFcn([],[]); ui=app.getDepthManager();
dialogCleanup=onCleanup(@()closeFigure(ui.figure));
ui.targets.Value=4; ui.scale.Value=.8; ui.applyButton.ButtonPushedFcn([],[]);
cfg=app.getConfig(); assert(isequal(cfg.depthProfiles{4},expected)); clear dialogCleanup
% 使用临时模板库验证保存和重开，不修改用户库。
file=[tempname '.json']; fileCleanup=onCleanup(@()removeFile(file));
ui=calligraphy_depth_manager(app.figure,cfg,app.getGlyph(),1,[],@(~)[],@(~,~)[],file);
dialogCleanup=onCleanup(@()closeFigure(ui.figure));
ui.name.Value='横—轻起重收'; ui.saveButton.ButtonPushedFcn([],[]);
stored=calligraphy_depth_templates('load',[],file);
assert(numel(stored)==1 && isequal(stored.points,original)); clear dialogCleanup
ui=calligraphy_depth_manager(app.figure,cfg,app.getGlyph(),1,[],@(~)[],@(~,~)[],file);
dialogCleanup=onCleanup(@()closeFigure(ui.figure));
assert(any(strcmp(ui.source.Items,'模板：横—轻起重收')));
ui.source.Value='模板：横—轻起重收'; ui.source.ValueChangedFcn([],[]);
drawnow; exportapp(ui.figure,fullfile(root,'tests','depth_reuse_preview.png'));
fprintf('DEPTH REUSE PASSED: cross-character batch, clipboard, multiplier, persistent template. No simulation.\n');
end
function closeFigure(f)
if isvalid(f), delete(f); end
end
function removeFile(file)
if isfile(file), delete(file); end
end
