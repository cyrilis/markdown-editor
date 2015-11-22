class MarkdownEditor
    constructor: (@elem,options) ->
        @defaultOption = {
            mode: 'gfm',
            lineNumbers: false,
            theme: 'default',
            lineWrapping: true
            tabSize: if (options.tabSize isnt undefined) then options.tabSize or 2,
            indentUnit: if (options.tabSize isnt undefined) then options.tabSize or 2,
            indentWithTabs: if (options.indentWithTabs is false) then false or true,
            lineNumbers: false,
            autofocus: if (options.autofocus is true) then true or false,
        }
        options = options or {}
        for k,v in options
            if @defaultOption[k] isnt undefined
                options[k] = @defaultOption[k]
        for k,v in @defaultOption
            if options[k] is undefined
                options[k] = @defaultOption[k]
        @options = options

        @cm = CodeMirror.fromTextArea(@elem, @options)
        if window.marked
            @uploadRenderer = new window.marked.Renderer()
            imageId = "image-" + btoa(Math.round(Math.random()*1000000000))
            imageId = imageId.replace("=", "")
            @uploadRenderer.image = (href, title, text)->
                hasImage = true
                doneClass = ""
                if href.length <= 9 and (href is ("https://").substr(0, href.length) or href is ("http://").substr(0, href.length))
                    hasImage = false
                if hasImage
                    doneClass = " done"
                out = '<div class="image-uploader"><figure><img src="' + href + '" alt="' + text + '"' + doneClass
                if title
                    out += ' title="' + title + '"'
                out += (if this.options.xhtml? then '/>' else '>')
                out += '<div class="image-uploader-handler'+doneClass+'">'+
                    '<div class="remove"><i class="icon-close"></i></div>'+
                    '<input type="hidden" id='+imageId+' value='+imageId+'/>'+
                    '<div class="image-add-file">Click to Upload Image</div>' +
                    '<div class="image-progress">' +
                    '<div class="image-progress-inner"></div>' +
                    '</div></div>';
                if title
                    out += "<figcaption>" + title + "</figcaption>"
                out += "</figure></div>"
                return out
        @buildDom()
        @cm.on "change", @renderPreview.bind(@)
        @bindClickDropdown()
        @renderPreview()
        @bindUpload()
        @action_split()
        @syncScroll()
        self = @
        $( document ).ready ()=>
            window.setTimeout ->
                self.cm.refresh()
                console.log "Ready"
            ,300
        @

    buildDom: ()->
        self = @
        htmlTemplate = """
            <div class="note-editor panel panel-default">
                <div class="note-dropzone">
                    <div class="note-dropzone-message"></div>
                </div>
                <div class="note-toolbar panel-heading">
                </div>
                <div class="note-editing-area">
                    <div class="note-editable panel-body" style="height: 500px;"></div>
                </div>
                <div class="note-statusbar">
                    <div class="note-resizebar">
                        <div class="note-icon-bar"></div>
                        <div class="note-icon-bar"></div>
                        <div class="note-icon-bar"></div>
                    </div>
                </div>
            </div>
        """

        uploadForm = """
            <form class="image-uploader-form" target="_blank" hidden="hidden">
                <input name="image" class="image-uploader-input" type="file"/>
                <input type="hidden" name="id" value=""/>
            </form>
        """
        $("body").append $(uploadForm)

        @editorWrapper = $(htmlTemplate)
        items = @toolbarItems()
        for item in items
            ((item)->
                $itemTemplate = $(item.template)
                self.editorWrapper.find(".note-toolbar").append($itemTemplate)
                if item.name not in ["style", "table"]
                    action = item.action
                    $itemTemplate.find("button.btn.btn-default").eq(0).click ()->
                        self["action_" + action]()
                else if item.name is "style"
                    $itemTemplate.find(".dropdown-menu > li > a").click (e)->
                        e.preventDefault()
                        action = $(this).data("value")
                        self["action_" + action]()
                else if item.name is "table"
                    $catcher = $itemTemplate.find(".note-dimension-picker-mousecatcher")
                    $catcher.on "mousemove", (event)->
                        onMovePicker(event)
                    .parent().click ()->
                        self["action_" + "table"]($catcher.attr("data-value"))
                    onMovePicker = (event)->
                        $picker = $(event.target.parentNode)
                        $dimensionDisplay = $picker.next()
                        $catcher = $picker.find('.note-dimension-picker-mousecatcher')
                        $highlighted = $picker.find('.note-dimension-picker-highlighted')
                        $unhighlighted = $picker.find('.note-dimension-picker-unhighlighted')

                        posOffset = undefined
                        if (event.offsetX == undefined)
                            posCatcher = $(event.target).offset()
                            posOffset = {
                                    x: event.pageX - posCatcher.left,
                                    y: event.pageY - posCatcher.top
                                };
                        else
                            posOffset = {
                                x: event.offsetX,
                                y: event.offsetY
                            };
                        dim = {
                            c: Math.ceil(posOffset.x / 18) || 1,
                            r: Math.ceil(posOffset.y / 18) || 1
                        }
                        $highlighted.css({ width: dim.c + 'em', height: dim.r + 'em' })
                        $catcher.attr('data-value', dim.c + 'x' + dim.r)
                        if (3 < dim.c && dim.c < 10)
                            $unhighlighted.css({ width: dim.c + 1 + 'em'})
                        if (3 < dim.r && dim.r < 10)
                            $unhighlighted.css({ height: dim.r + 1 + 'em'})
                        $dimensionDisplay.html(dim.c + ' x ' + dim.r)
            )(item)
        $(@cm.display.wrapper).after(@editorWrapper)
        options = @options
        elemName = @elem.name
        $htmlPreview = $("""
        <div class="content-preview"></div>
        <textarea hidden class='html-value' name="#{options.htmlName or (elemName+'-html')}"/>
        """)
        @editorWrapper.find(".note-editing-area .note-editable").append(@cm.display.wrapper).append($htmlPreview)
        @preview = @editorWrapper.find(".content-preview")

    createIcon: (name, action, icon, shortCut)->
        template = """
            <div class="btn-group #{ if name is 'fullscreen' then 'note-fullscreen' else 'note-base'}">
                <button type="button" class="btn btn-default btn-sm" title="" data-event="#{action}" tabindex="-1"
                    data-name="#{name}" data-original-title="#{shortCut}"><i class="#{icon}"></i></button>
            </div>
        """
        return {
            template: template,
            name: name,
            action: action
        }

    toolbarItems: ()->
        [{
            name: "style"
            template: """
                <div class="note-style btn-group">
                    <div class="btn-group" data-name="style">
                        <button type="button" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown" title=""
                                tabindex="-1" data-original-title="Style"><i class="icon-magic"></i> <span
                                class="caret"></span></button>
                        <ul class="dropdown-menu">
                            <li><a data-event="formatBlock" href="#" data-value="h1">Header 1</a></li>
                            <li><a data-event="formatBlock" href="#" data-value="h2">Header 2</a></li>
                            <li><a data-event="formatBlock" href="#" data-value="h3">Header 3</a></li>
                            <li><a data-event="formatBlock" href="#" data-value="h4">Header 4</a></li>
                            <li><a data-event="formatBlock" href="#" data-value="h5">Header 5</a></li>
                            <li><a data-event="formatBlock" href="#" data-value="h6">Header 6</a></li>
                        </ul>
                    </div>
                </div>
            """
            action: "switchStyle"
        },
        @createIcon("bold", "bold", "icon-bold", "Bold (⌘+B)"),
        @createIcon("italic", "italic", "icon-italic", "Italic (⌘+I)"),
        @createIcon("strikethrough", "strikethrough", "icon-strikethrough", "Strike through"),
        @createIcon("ul", "unorderedList", "icon-list-ul", "Unordered list (⌘+⇧+NUM7)"),
        @createIcon("ol", "orderedList", "icon-list-ol", "Ordered list (⌘+⇧+NUM8)"),
        @createIcon("code", "code", "icon-code", "Code (Ctrl+Alt+C)"),
        @createIcon("quote", "quote", "icon-quote", "Quote (Ctrl+')"),
        @createIcon("link", "link", "icon-link", "Create Link (Ctrl+K)"),
        @createIcon("image", "image", "icon-image", "Insert Image (Ctrl+Alt+I)"),
        {
            template: """
                    <div class="note-table btn-group">
                        <div class="btn-group" data-name="table">
                            <button type="button" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown" title=""
                                    tabindex="-1" data-original-title="Table"><i class="icon-table"></i> <span
                                    class="caret"></span></button>
                            <ul class="dropdown-menu note-table">
                                <div class="note-dimension-picker">
                                    <div class="note-dimension-picker-mousecatcher" data-event="insertTable" data-value="1x1"
                                         style="width: 10em; height: 10em;"></div>
                                    <div class="note-dimension-picker-highlighted"></div>
                                    <div class="note-dimension-picker-unhighlighted"></div>
                                </div>
                                <div class="note-dimension-display"> 1 x 1</div>
                            </ul>
                        </div>
                    </div>
                """
            action: "table"
            name: "table"
        },
        @createIcon("hr", "hr", "icon-minus", "Insert Horizontal Rule (⌘+ENTER)"),
        @createIcon("split", "split", "icon-columns", "Split Preview and Markdown"),
        @createIcon("preview", "preview", "icon-see", "Preview Markdown"),
        @createIcon("fullscreen", "fullscreen", "icon-fullscreen", "Full Screen")
        ]

    bindClickDropdown: ()->
        @editorWrapper.find('.btn[data-toggle="dropdown"]').click ()->
            console.log("xxx")
            $(@).parent().toggleClass("open")

        @editorWrapper.find(".dropdown-menu>li>a").click ()->
            $(@).parents(".dropdown-menu").parent().removeClass("open")

        @editorWrapper.find(".note-dimension-picker").click ()->
            $(@).parents(".dropdown-menu").parent().removeClass("open")

    action_fullscreen: ()->
        isFullScreen = @editorWrapper.find(".note-fullscreen .btn").eq(0).toggleClass("active").hasClass("active")
        @editorWrapper.toggleClass("fullscreen", isFullScreen)
        @cm.refresh()
        $window = $(window)
        $scrollbar = $("html, body")
        $toolbar = @editorWrapper.find(".note-toolbar")
        $editable = @editorWrapper.find(".note-editable")
        resize = (size)->
            $editable.css("height", size.h)

        if isFullScreen
            $editable.data("orgheight", $editable.css("height"))
            $window.on 'resize', ()->
                resize({
                    h: $window.height() - $toolbar.outerHeight()
                })
            .trigger("resize");
            $scrollbar.css("overflow", "hidden");
        else
            $window.off "resize"
            resize {
                h: $editable.data("orgheight")
            }
            $scrollbar.css("overflow", "visible")

    getNthImageSelection: (n, toReplace)->
        editor = @cm
        reg = /(!\[.*?\]\()([^'"]+?)?(['"][^'"]*['"])?\s*(\))/gi
        cursor = editor.getSearchCursor(reg)
        for i in [0...n]
            cursor.findNext()
        if not cursor.find() then return null
        editor.setSelection(cursor.from(), cursor.to())
        text = editor.getSelection(cursor.from(), cursor.to())
        text.replace(reg, (whole, title, link, desc, last)->
            toReplace = (title || "") + (toReplace || "") + " " + (desc||"") + (last||"")
            cursor.replace(toReplace)
        )

    bindUpload: ()->
        self = @
        $body = $("body")
        $body.on "click", ".image-uploader-handler.done .remove", ()->
            $imageUploaderHandler = $(this).parents(".image-uploader-handler")
            $imageUploaderHandler.removeClass("done")
            path = "http://"
            $imageUploaderHandler.parents("figure").find("img").attr("src", path)
            $imageUploaderHandler.addClass("done")
            n = $(".image-uploader-handler").index($imageUploaderHandler)
            self.getNthImageSelection(n, path)

        $body.on "click", ".image-uploader-handler", ()->
            if $(this).hasClass("done")
                return false
            id = $(this).find("input").attr("id");
            $imageUploaderInput = $(".image-uploader-input")
            $imageUploaderHandler = $(this)
            $(".image-uploader-form").find("[name='id']").val(id)
            $imageUploaderInput.click()
            $imageUploaderInput.off("change")
            $imageUploaderInput.on "change", (e)->
                if (!$(this).val()) then return false
                formData = new FormData($(".image-uploader-form").get(0));
                $.ajax({
                    url: "/upload"
                    type: "POST"
                    xhr: ()->
                        xhr = $.ajaxSettings.xhr()
                        if xhr.upload
                            xhr.upload.addEventListener("progress", (e)->
                                width = "" + Math.round(e.loaded / e.total * 100) + "%"
                                $imageUploaderHandler.find(".image-progress-inner").width(width)
                            , false)
                        return xhr
                    data: formData
                    error: ()->
                    success: (result)->
                        if result.error
                            console.log "Failed to upload", result.error, result.message
                            $imageUploaderHandler.removeClass("pending")
                            return false
                        path = result.path
                        $imageUploaderHandler.parents("figure").find("img").attr("src", path)
                        $imageUploaderHandler.find(".image-progress-inner").width(0)
                        n = $(".image-uploader-handler").index($imageUploaderHandler)
                        self.getNthImageSelection(n, path)
                        window.setTimeout ()->
                            $(".image-uploader-handler").eq(n).addClass("done").parent().find("img").addClass("done")
                        ,10
                    cache: false,
                    processData: false,
                    contentType: false,
                    beforeSend: ()->
                        $imageUploaderHandler.addClass("pending")
                })

    formatBlock: (type, start_charts, end_chars)->
        end_chars = if (typeof end_chars == "undefined") then start_charts else end_chars
        cm = @cm
        stat = @getState()

        start = start_charts
        end = end_chars
        startPoint = cm.getCursor('start')
        endPoint = cm.getCursor('end')

        if stat[type]
            text = cm.getLine(startPoint.line)
            start = text.slice(0, startPoint.ch)
            end = text.slice(startPoint.ch)
            if type == "bold"
                start = start.replace /(\*\*|__)(?![\s\S]*(\*\*|__))/, ""
                end = end.replace(/(\*\*|__)/, "")
            else if(type == "italic")
                start = start.replace(/(\*|_)(?![\s\S]*(\*|_))/, "");
                end = end.replace(/(\*|_)/, "");
            else if(type == "strikethrough")
                start = start.replace(/(\*\*|~~)(?![\s\S]*(\*\*|~~))/, "");
                end = end.replace(/(\*\*|~~)/, "")
            cm.replaceRange(start + end, {
                line: startPoint.line,
                ch: 0
            }, {
                line: startPoint.line,
                ch: 999999999999999
            })

            if type is "bold" or type is "strikethrough"
                startPoint.ch -= 2
                if startPoint isnt endPoint
                    endPoint.ch -= 2
            else if type is "italic"
                startPoint.ch -= 1
                if startPoint isnt endPoint
                    endPoint.ch -= 1
        else
            text = cm.getSelection()
            if type is "bold"
                text = text.split("**").join("");
                text = text.split("__").join("");
            else if type is "italic"
                text = text.split("*").join("");
                text = text.split("_").join("");
            else if type is "strikethrough"
                text = text.split("~~").join("");
            cm.replaceSelection(start + text + end)

            startPoint.ch += start_charts.length
            endPoint.ch = startPoint.ch + text.length

        cm.setSelection(startPoint, endPoint)
        cm.focus()

    formatLine: (name)->
        cm = @cm
        stat = @getState()
        startPoint = cm.getCursor("start")
        endPoint = cm.getCursor("end")
        repl = {
            'quote': /^(\s*)\>\s+/,
            'unordered-list': /^(\s*)(\*|\-|\+)\s+/,
            'ordered-list': /^(\s*)\d+\.\s+/
        }
        map = {
            'quote': '> ',
            'unordered-list': '* ',
            'ordered-list': '1. '
        }

        for i in [startPoint.line..endPoint.line]
            ((i)->
                text = cm.getLine(i)
                if stat[name]
                    text = text.replace(repl[name], "$1")
                else
                    text = map[name] + text
                cm.replaceRange(text, {
                    line: i,
                    ch: 0
                }, {
                    line: i,
                    ch: 9999999999
                })
            )(i)
        cm.focus()

    formatHeading: (direction, size)->
        cm = @cm
        startPoint = cm.getCursor("start")
        endPoint = cm.getCursor("end")
        for i in [startPoint.line..endPoint.line]
            ((i)->
                text = cm.getLine(i)
                currHeadingLevel = text.search(/[^#]/)
                if direction isnt undefined
                    if currHeadingLevel <= 0
                        if direction is "bigger"
                            text = "######" + text
                        else
                            text = "#" + text
                    else if currHeadingLevel is 6 and direction is "smaller"
                        text = text.substr 7
                    else if currHeadingLevel is 1 and direction is "bigger"
                        text = text.substr 2
                    else
                        if direction is "bigger"
                            text = text.substr 1
                        else
                            text = "#" + text
                else
                    if size > 6 then return false
                    if currHeadingLevel <= 0
                        text = Array(size + 1).join("#") + " " + text
                    else if currHeadingLevel is size
                        text = text.substr (currHeadingLevel + 1)
                    else
                        text = Array(size + 1).join("#") + " " + text.substr (currHeadingLevel + 1)

                cm.replaceRange(text, {
                    line: i,
                    ch: 0
                }, {
                    line: i,
                    ch: 99999999999999
                });
            )(i)

    replaceSection: (active, start, end)->
        cm = @cm
        startPoint = cm.getCursor("start")
        endPoint = cm.getCursor("end")
        if (active)
            text = cm.getLine(startPoint.line)
            start = text.slice(0, startPoint.ch)
            end = text.slice(startPoint.ch)
            cm.replaceRange(start+end, {
                line: startPoint.line,
                ch: 0
            })
        else
            text = cm.getSelection()
            cm.replaceSelection(start + text + end)

            startPoint.ch += start.length
            if startPoint isnt endPoint
                endPoint.ch += start.length

        cm.setSelection(startPoint, endPoint)
        cm.focus()

    undo: ()->
        @cm.undo();
        @cm.focus()

    redo: ()->
        @cm.redo()
        @cm.focus()

    action_hr: ()->
        stat = @getState()
        @replaceSection(stat.image, "", '\n\n-----\n\n')

    action_image: ()->
        stat = @getState()
        @replaceSection(stat.image, '![](http://', ')')

    action_link: ()->
        stat = @getState()
        @replaceSection(stat.link, '[', '](http://)')

    action_orderedList: ()->
        @formatLine('ordered-list');

    action_unorderedList: ()->
        @formatLine("unordered-list")

    action_h1: ()->
        @formatHeading(undefined , 1)

    action_h2: ()->
        @formatHeading(undefined , 2)

    action_h3: ()->
        @formatHeading(undefined , 3)

    action_h4: ()->
        @formatHeading(undefined , 4)

    action_h5: ()->
        @formatHeading(undefined , 5)

    action_h6: ()->
        @formatHeading(undefined , 6)

    action_headerBigger: ()->
        @formatHeading("bigger")

    action_headerSmaller: ()->
        @formatHeading("smaller")

    action_quote: ()->
        @formatLine("quote")

    action_code: ()->
        @formatBlock("code", '```\r\n', '\r\n```')

    action_strikethrough: ()->
        @formatBlock('strikethrough', '~~')

    action_italic: ()->
        @formatBlock("italic", "*")

    action_bold: ()->
        @formatBlock("bold", "**")

    action_table: (axb)->
        [a,b] = axb.split("x")
        line = Array(+a+1).join("\|\ \ \ ") + "\|"
        lineHead = Array(+a+1).join("\|\-\-\-") + "\|"
        br = "\n"
        startText = "\n\|"
        endText = line.slice(1) + br + lineHead + br + Array(+b+1).join(line + br)
        @formatBlock("table", startText, endText)

    action_preview: ()->
        @editorWrapper.removeClass("split").toggleClass("preview")
        @cm.refresh()

    action_split: ()->
        isSplit = not @editorWrapper.hasClass("split")
        @editorWrapper.toggleClass("split", isSplit).toggleClass("preview", isSplit)
        @cm.refresh()

    getState: (pos)->
        pos = pos || @cm.getCursor("start")
        stat = @cm.getTokenAt(pos)
        if not stat.type
            return {}
        types = stat.type.split(" ")
        ret = {}
        for data in types
            if data is "strong"
                ret.bold = true
            else if data is "variable-2"
                    text = @cm.getLine(pos.line)
                    if(/^\s*\d+\.\s/.test(text))
                        ret['ordered-list'] = true
                    else
                        ret['unordered-list'] = true
            else if data is "atom"
                ret.quote = true
            else if data is "em"
                ret.italic = true
            else if data is "quote"
                ret.quote = true
            else if data is "strikethrough"
                ret.strikethrough = true
            else if data is "comment"
                ret.code = true
        return ret

    renderPreview: ()->
        self = @
        text = @cm.getValue()
        if window.marked
            window.marked.setOptions {
                gfm: true
            }
            window.marked(text, {
                renderer: self.uploadRenderer
            }, (err, content)->
                if err
                    return console.log(err)
                self.preview.html(content)
                pureValue = $("<div>").html(content).find(".image-uploader-handler").remove().end().find(".image-uploader").removeClass("image-uploader").addClass("figure-wrapper").end().html()
                self.editorWrapper.find(".html-value").val(pureValue)
                self.highlight()
            )

    highlight: ()->
        $(".content-preview").find("pre code").parent().each ()->
            $(this).addClass("prettyprint linenums")
        prettyPrint()
    syncScroll: ()->
        $text = $(".CodeMirror-scroll")
        $html = $(".content-preview")
        self = @
        $text.scroll ()->
            top = $text.scrollTop()
            winHeight = $text.height()
            textHeight = $(".CodeMirror-sizer").height()
            htmlHeight = self.editorWrapper.find(".content-preview").get(0).scrollHeight
            scrollTop = top * ( htmlHeight - winHeight ) / ( textHeight - winHeight )
            $html.scrollTop(scrollTop);

window.MarkdownEditor = MarkdownEditor