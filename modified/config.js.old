/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
	// Define changes to default configuration here.
	// http://docs.cksource.com/ckeditor_api/symbols/CKEDITOR.config.html
	
	config.width = 850;
	config.contentsCss = '/static/css/main.css';
	
	config.forcePasteAsPlainText = 'true';
	
// WBRASWELL 20140921 2014.264: enable appropriate WYSIWYG HTML editing tools

	config.toolbar_Custom = [
//		['Source','-','Bold','Italic','Strike'],
//		['Source','Maximize','-','Bold','Italic','Underline'],
		['Source','Maximize'],
		['Cut','Copy','Paste','PasteText','PasteFromWord','SpellChecker'],
		['Link','Unlink','Image','Table'],
        ['Bold','Italic','Underline'],
		['FontSize','TextColor'],
		['NumberedList','BulletedList','Outdent','Indent','Blockquote'],
		['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
	];

/*
    config.toolbar_Custom =
    [
        { name: 'document',    items : [ 'Source','-','Save','NewPage','DocProps','Preview','Print','-','Templates' ] },
        { name: 'clipboard',   items : [ 'Cut','Copy','Paste','PasteText','PasteFromWord','-','Undo','Redo' ] },
        { name: 'editing',     items : [ 'Find','Replace','-','SelectAll','-','SpellChecker', 'Scayt' ] },
//        { name: 'forms',       items : [ 'Form', 'Checkbox', 'Radio', 'TextField', 'Textarea', 'Select', 'Button', 'ImageButton', 'HiddenField' ] },
        '/',
        { name: 'basicstyles', items : [ 'Bold','Italic','Underline','Strike','Subscript','Superscript','-','RemoveFormat' ] },
//        { name: 'paragraph',   items : [ 'NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote','CreateDiv','-','JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock','-','BidiLtr','BidiRtl' ] },
        { name: 'paragraph',   items : [ 'NumberedList','BulletedList','-','Outdent','Indent','-','Blockquote','-','JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock' },
        { name: 'links',       items : [ 'Link','Unlink','Anchor' ] },
//        { name: 'insert',      items : [ 'Image','Flash','Table','HorizontalRule','Smiley','SpecialChar','PageBreak' ] },
        { name: 'insert',      items : [ 'Image','Table','HorizontalRule','Smiley','SpecialChar','PageBreak' ] },
        '/',
        { name: 'styles',      items : [ 'Styles','Format','Font','FontSize' ] },
        { name: 'colors',      items : [ 'TextColor','BGColor' ] },
//        { name: 'tools',       items : [ 'Maximize', 'ShowBlocks','-','About' ] }
        { name: 'tools',       items : [ 'Maximize' ] }
    ];
*/

//	config.toolbar = 'Full';
	config.toolbar = 'Custom';
//	config.toolbar = 'CustomExtended';
	
	config.menu_groups = 'clipboard,anchor,link,image';
	
	// ShinyCMS File Manager
	config.filebrowserBrowseUrl      = '/admin/filemanager/view';
	config.filebrowserImageBrowseUrl = '/admin/filemanager/view/images';
	config.filebrowserUploadUrl      = '/admin/filemanager/upload';
	config.filebrowserImageUploadUrl = '/admin/filemanager/upload/images';
	config.filebrowserWindowWidth    = '800';
	config.filebrowserWindowHeight   = '600';
};
