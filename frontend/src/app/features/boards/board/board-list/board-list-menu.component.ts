//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  Component, EventEmitter, Input, Output, inject,
} from '@angular/core';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { AuthorisationService } from 'core-app/core/model-auth/model-auth.service';
import { OpModalService } from 'core-app/shared/components/modal/modal.service';
import { IsolatedQuerySpace } from 'core-app/features/work-packages/directives/query-space/isolated-query-space';
import { Board } from 'core-app/features/boards/board/board';
import { BoardActionsRegistryService } from 'core-app/features/boards/board/board-actions/board-actions-registry.service';
import { OpContextMenuItem } from 'core-app/shared/components/op-context-menu/op-context-menu.types';
import { BoardService } from 'core-app/features/boards/board/board.service';
import { BoardActionService } from 'core-app/features/boards/board/board-actions/board-action.service';
import { GridWidgetResource } from 'core-app/features/hal/resources/grid-widget-resource';
import { WidgetChangeset } from 'core-app/shared/components/grids/widgets/widget-changeset';
import { HalResourceService } from 'core-app/features/hal/services/hal-resource.service';

@Component({
  selector: 'board-list-menu',
  templateUrl: './board-list-menu.component.html',
  standalone: false,
})
export class BoardListMenuComponent {
  @Input() board:Board;

  @Input() resource:GridWidgetResource;

  @Output() onRemove = new EventEmitter<void>();

  private halResourceService = inject(HalResourceService);

  constructor(readonly opModalService:OpModalService,
    readonly authorisationService:AuthorisationService,
    private readonly querySpace:IsolatedQuerySpace,
    private readonly boardService:BoardService,
    private readonly boardActionRegistry:BoardActionsRegistryService,
    readonly I18n:I18nService) {
  }

  public get menuItems() {
    return async () => {
      const items:OpContextMenuItem[] = [
        {
          disabled: !this.canManage,
          linkText: 'Set WIP Limit',
          onClick: () => {
            this.setWipLimit();
            return true;
          },
        },
        {
          disabled: !this.canDelete,
          linkText: this.I18n.t('js.boards.lists.delete'),
          onClick: () => {
            this.onRemove.emit();
            return true;
          },
        },
      ];

      // Add action specific menu entries
      if (this.board.isAction) {
        const additional = await this.actionService.getAdditionalListMenuItems(this.query);
        return items.concat(additional);
      }

      return items;
    };
  }

  /**
   * Return the linked action service
   */
  private get actionService():BoardActionService {
    return this.boardActionRegistry.get(this.board.actionAttribute!);
  }

  private get canManage() {
    return this.boardService.canManage(this.board);
  }

  public canDelete() {
    return this.canManage && !!this.query.delete;
  }

  private async setWipLimit() {
    const current = this.resource.options.wipLimit as number || 0;
    const value = window.prompt('Set Work In Progress (WIP) limit for this column (0 for no limit):', current.toString());

    if (value !== null) {
      const limit = parseInt(value, 10);
      const changeset = new WidgetChangeset(this.resource);
      changeset.setValue('options', { ...this.resource.options, wipLimit: limit > 0 ? limit : null });

      const payload = await changeset.buildRequestPayload();

      this.halResourceService.patch<GridWidgetResource>(this.resource.href!, payload)
        .subscribe(() => {
          // Trigger a refresh of the board to show the new limit
          window.location.reload();
        });
    }
  }

  private get query() {
    return this.querySpace.query.value!;
  }
}
