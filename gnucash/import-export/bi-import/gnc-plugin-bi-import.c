/*
 * gnc-plugin-bi-import.c -- Invoice Importer Plugin
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, contact:
 *
 * Free Software Foundation           Voice:  +1-617-542-5942
 * 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652
 * Boston, MA  02110-1301,  USA       gnu@gnu.org
 */

/**
 * @internal
 * @file gnc-plugin-bi-import.c
 * @brief Plugin registration of the bi-import plugin
 * @author Copyright (C) 2009 Sebastian Held <sebastian.held@gmx.de>
 */


#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#include <glib/gi18n.h>

#include "dialog-utils.h"

#include "gnc-plugin-bi-import.h"
#include "dialog-bi-import-gui.h"
#include "gnc-plugin-manager.h"

/* This static indicates the debugging module that this .o belongs to.  */
static QofLogModule log_module = G_LOG_DOMAIN;

static void gnc_plugin_bi_import_class_init         (GncPluginbi_importClass *klass);
static void gnc_plugin_bi_import_init               (GncPluginbi_import *plugin);
static void gnc_plugin_bi_import_finalize           (GObject *object);

/* Command callbacks */
static void gnc_plugin_bi_import_cmd_test (GSimpleAction *simple, GVariant *parameter, gpointer user_data);

#define PLUGIN_ACTIONS_NAME "gnc-plugin-bi-import-actions"
#define PLUGIN_UI_FILENAME  "gnc-plugin-bi-import.ui"

static GActionEntry gnc_plugin_actions [] =
{
    { "bi_importAction", gnc_plugin_bi_import_cmd_test, NULL, NULL, NULL },
};
/** The number of actions provided by this plugin. */
static guint gnc_plugin_n_actions = G_N_ELEMENTS(gnc_plugin_actions);

/** The default menu items that need to be add to the menu */
static const gchar *gnc_plugin_load_ui_items [] =
{
    "FilePlaceholder1",
    NULL,
};

/************************************************************
 *                   Object Implementation                  *
 ************************************************************/

G_DEFINE_TYPE(GncPluginbi_import, gnc_plugin_bi_import, GNC_TYPE_PLUGIN)

GncPlugin *
gnc_plugin_bi_import_new (void)
{
    return GNC_PLUGIN (g_object_new (GNC_TYPE_PLUGIN_BI_IMPORT, (gchar*) NULL));
}

static void
gnc_plugin_bi_import_class_init (GncPluginbi_importClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    GncPluginClass *plugin_class = GNC_PLUGIN_CLASS(klass);

    object_class->finalize = gnc_plugin_bi_import_finalize;

    /* plugin info */
    plugin_class->plugin_name  = GNC_PLUGIN_BI_IMPORT_NAME;

    /* widget addition/removal */
    plugin_class->actions_name    = PLUGIN_ACTIONS_NAME;
    plugin_class->actions         = gnc_plugin_actions;
    plugin_class->n_actions       = gnc_plugin_n_actions;
    plugin_class->ui_filename     = PLUGIN_UI_FILENAME;
    plugin_class->ui_updates      = gnc_plugin_load_ui_items;
}

static void
gnc_plugin_bi_import_init (GncPluginbi_import *plugin)
{
}

static void
gnc_plugin_bi_import_finalize (GObject *object)
{
}

/************************************************************
*                    Plugin Bootstrapping                   *
************************************************************/

void
gnc_plugin_bi_import_create_plugin (void)
{
    GncPlugin *plugin = gnc_plugin_bi_import_new ();

    gnc_plugin_manager_add_plugin (gnc_plugin_manager_get (), plugin);
}

/************************************************************
 *                    Command Callbacks                     *
 ************************************************************/

static void
gnc_plugin_bi_import_cmd_test (GSimpleAction *simple,
                               GVariant      *parameter,
                               gpointer       user_data)
{
    GncMainWindowActionData *data = user_data;

    ENTER ("action %p, main window data %p", simple, data);
    PINFO ("bi_import");

    gnc_plugin_bi_import_showGUI(GTK_WINDOW(data->window));

    LEAVE (" ");
}
